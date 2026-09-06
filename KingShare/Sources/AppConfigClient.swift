import Foundation

struct StartupConfig {
    var latestVersion = ""
    var minimumVersion = ""
    var updateMode = 0
    var downloadApk = ""
    var updateDescription = ""
    var noticeOpen = false
    var noticeTitle = ""
    var noticeContent = ""
    var noticeButton = "查看详情"
    var noticeLink = ""
    var noticeLimit = 1
    var privacyUrl = ""
    var agreementUrl = ""
    var payOpen = false
    var activityPopOpen = false
    var statisticsOpen = false
    var customerServiceOpen = false
}

struct StartupConfigResult {
    let config: StartupConfig?
    let fromCache: Bool
    let authorizationRejected: Bool
    let errorMessage: String?
}

/// Backend auth credentials from Config.plist (XOR 0x5A + Base64, same protection as Android).
enum Config {
    static let merchantPayload: String = plist("MerchantPayload")
    static let signaturePayload: String = plist("ClientSignaturePayload")

    private static func plist(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dict[key] as? String else { return "" }
        return value
    }
}

/// 1:1 port of the Android AppConfigClient (URL, headers, cache and error mapping).
enum AppConfigClient {
    static let configURL = URL(string: "https://seayun.weilua.top/api/client/config")!
    private static let cacheKey = "startup_config_last_valid_config"

    static func fetch(callback: @escaping (StartupConfigResult) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result = fetchBlocking()
            DispatchQueue.main.async { callback(result) }
        }
    }

    private static func fetchBlocking() -> StartupConfigResult {
        let merchant = restoreCredential(Config.merchantPayload).trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = restoreCredential(Config.signaturePayload).trimmingCharacters(in: .whitespacesAndNewlines)
        if merchant.isEmpty || signature.isEmpty {
            return StartupConfigResult(config: readCache(), fromCache: true, authorizationRejected: false, errorMessage: "客户端鉴权配置为空")
        }
        var request = URLRequest(url: configURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("close", forHTTPHeaderField: "Connection")
        request.setValue(Theme.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(merchant, forHTTPHeaderField: "X-Merchant-Code")
        request.setValue(signature, forHTTPHeaderField: "X-Client-Signature")

        var result: StartupConfigResult?
        let sem = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            result = handle(data: data, response: response as? HTTPURLResponse, error: error)
            sem.signal()
        }
        task.resume()
        sem.wait()
        return result ?? StartupConfigResult(config: readCache(), fromCache: true, authorizationRejected: false, errorMessage: "后台请求异常")
    }

    private static func handle(data: Data?, response: HTTPURLResponse?, error: Error?) -> StartupConfigResult {
        if let status = response?.statusCode {
            if status == 200, let body = data, let text = String(data: body, encoding: .utf8) {
                if let config = parse(text) {
                    UserDefaults.standard.set(text, forKey: cacheKey)
                    return StartupConfigResult(config: config, fromCache: false, authorizationRejected: false, errorMessage: nil)
                }
                return StartupConfigResult(config: readCache(), fromCache: true, authorizationRejected: false, errorMessage: "后台返回内容格式错误")
            }
            let errorBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let reason: String
            if status == 403 {
                reason = "后台拒绝客户端授权（403）"
            } else if status == 503 {
                reason = "后台服务暂不可用（503）"
            } else {
                reason = "后台返回错误（\(status)）"
            }
            var detail: String?
            if !errorBody.isEmpty {
                if let obj = try? JSONSerialization.jsonObject(with: errorBody.data(using: .utf8) ?? Data()) as? [String: Any],
                   let msg = obj["msg"] as? String, !msg.isEmpty {
                    detail = msg
                }
            }
            return StartupConfigResult(config: readCache(), fromCache: true, authorizationRejected: status == 403, errorMessage: detail.map { "\(reason)：\($0)" } ?? reason)
        }
        let nsError = error as NSError?
        if nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorTimedOut {
            return StartupConfigResult(config: readCache(), fromCache: true, authorizationRejected: false, errorMessage: "连接后台超时，请检查网络")
        }
        return StartupConfigResult(config: readCache(), fromCache: true, authorizationRejected: false, errorMessage: "无法连接后台：\(error?.localizedDescription ?? "网络异常")")
    }

    private static func parse(_ body: String) -> StartupConfig? {
        guard let data = body.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["code"] as? NSNumber)?.intValue == 200 else { return nil }
        let version = (root["version_info"] as? [String: Any]) ?? [:]
        let functions = (root["function_switch"] as? [String: Any]) ?? [:]
        let notice = (root["notice_pop"] as? [String: Any]) ?? [:]
        let law = (root["law_doc"] as? [String: Any]) ?? [:]
        var config = StartupConfig()
        config.latestVersion = (version["latest_ver"] as? String) ?? ""
        config.minimumVersion = (version["min_allow_ver"] as? String) ?? ""
        config.updateMode = (version["update_mode"] as? NSNumber)?.intValue ?? 0
        config.downloadApk = (version["download_apk"] as? String) ?? ""
        config.updateDescription = (version["update_desc"] as? String) ?? ""
        config.noticeOpen = (notice["pop_open"] as? NSNumber)?.boolValue ?? false
        config.noticeTitle = (notice["title"] as? String) ?? ""
        config.noticeContent = (notice["content"] as? String) ?? ""
        config.noticeButton = (notice["btn_text"] as? String) ?? "查看详情"
        config.noticeLink = (notice["pop_link"] as? String) ?? ""
        config.noticeLimit = max((notice["limit_show"] as? NSNumber)?.intValue ?? 1, 0)
        config.privacyUrl = (law["privacy_url"] as? String) ?? ""
        config.agreementUrl = (law["user_agreement"] as? String) ?? ""
        config.payOpen = (functions["pay_open"] as? NSNumber)?.boolValue ?? false
        config.activityPopOpen = (functions["activity_pop"] as? NSNumber)?.boolValue ?? false
        config.statisticsOpen = (functions["stat_sdk"] as? NSNumber)?.boolValue ?? false
        config.customerServiceOpen = (functions["customer_service"] as? NSNumber)?.boolValue ?? false
        return config
    }

    private static func readCache() -> StartupConfig? {
        return UserDefaults.standard.string(forKey: cacheKey).flatMap(parse)
    }

    private static func restoreCredential(_ payload: String) -> String {
        guard let data = Data(base64Encoded: payload) else { return "" }
        let bytes = data.map { $0 ^ 0x5A }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
