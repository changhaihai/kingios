import UIKit

/// 1:1 port of the Android QqAvatarLoader (qlogo.cn avatars, in-memory cache).
final class QqAvatarLoader {
    static let shared = QqAvatarLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "qq-avatar", qos: .utility, attributes: .concurrent)

    func load(qq: String, callback: @escaping (UIImage?) -> Void) {
        let normalized = qq.trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else {
            callback(nil)
            return
        }
        if let cached = cache.object(forKey: normalized as NSString) {
            callback(cached)
            return
        }
        queue.async {
            if let cached = self.cache.object(forKey: normalized as NSString) {
                DispatchQueue.main.async { callback(cached) }
                return
            }
            guard let url = URL(string: "https://q1.qlogo.cn/g?b=qq&nk=\(normalized)&s=100") else {
                DispatchQueue.main.async { callback(nil) }
                return
            }
            var image: UIImage?
            let sem = DispatchSemaphore(value: 0)
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
            URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data { image = UIImage(data: data) }
                sem.signal()
            }.resume()
            sem.wait()
            if let image = image {
                self.cache.setObject(image, forKey: normalized as NSString)
            }
            DispatchQueue.main.async { callback(image) }
        }
    }
}
