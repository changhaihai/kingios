import UIKit

/// 1:1 port of the Android MainActivity.
final class MainViewController: UIViewController {

    private struct Contributor {
        let name: String
        let qq: String
    }

    private let contributors = [
        Contributor(name: "Detector", qq: "3272428480"),
        Contributor(name: "野马", qq: "2832593761"),
        Contributor(name: "柠檬", qq: "3143936863"),
        Contributor(name: "想做一只无忧无虑的🐒", qq: "1504685082"),
        Contributor(name: "锤子", qq: "3223299530"),
        Contributor(name: "鲁班", qq: "1528864311"),
        Contributor(name: "卡卡", qq: "3561880251"),
        Contributor(name: "ℒฺℴฺνℯ̶ฺ归̶零", qq: "3264403203"),
        Contributor(name: "S", qq: "343027390")
    ]

    private var homeShown = false
    private var selectedHome = true
    private var pendingStartupConfig: StartupConfigResult?
    private var splashReady = false
    private var startupResolved = false
    private var launchFlowStarted = false
    private var launchGateCompleted = false
    private var roomProbeInFlight = false

    private var launchStatus: UILabel?
    private var launchAction: UIButton?
    private var statusStripLabel: UILabel?
    private var roomField: UITextField?
    private var securityStatusLabel: UILabel?
    private var connectButton: UIButton?
    private var homeScroll: UIScrollView?
    private var aboutScroll: UIScrollView?
    private var homeTab: NavButton?
    private var aboutTab: NavButton?

    private var downloadDialog: ModalController?
    private var downloadProgress: UIProgressView?
    private var downloadPercent: UILabel?
    private var downloadSize: UILabel?
    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var downloadFinished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.pageBg
        CrashLog.start()
        KeepAlive.shared.start()
        showLaunchAnimation()
    }

    // MARK: - Splash + launch gate

    private func showLaunchAnimation() {
        let root = UIStackView()
        root.axis = .vertical
        root.alignment = .center
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            root.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            root.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
        ])

        let mark = brandMark(size: 42, fontSize: 22, radius: 9)
        mark.alpha = 0

        let title = UILabel()
        title.text = "王者共享"
        title.font = .boldSystemFont(ofSize: 19)
        title.textColor = Theme.textPrimary
        title.textAlignment = .center
        title.alpha = 0

        let subtitleText = "实时对局战术地图"
        let subtitle = UILabel()
        let subtitleAttr = NSMutableAttributedString(string: subtitleText)
        subtitleAttr.addAttribute(.kern, value: 0.22, range: NSRange(location: 0, length: subtitleText.count))
        subtitle.attributedText = subtitleAttr
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = Theme.textSecond
        subtitle.textAlignment = .center
        subtitle.alpha = 0

        let status = UILabel()
        status.text = "正在连接管理后台"
        status.font = .systemFont(ofSize: 11)
        status.textColor = Theme.textSecond
        status.textAlignment = .center
        status.alpha = 0
        launchStatus = status

        let action = UIButton(type: .system)
        action.setTitle("重新验证", for: .normal)
        action.setTitleColor(Theme.textPrimary, for: .normal)
        action.titleLabel?.font = .systemFont(ofSize: 12)
        action.backgroundColor = Theme.cardBg
        action.layer.cornerRadius = 6
        action.layer.borderWidth = 1
        action.layer.borderColor = Theme.borderLight.cgColor
        action.isHidden = true
        action.addTarget(self, action: #selector(retryLaunch), for: .touchUpInside)
        launchAction = action

        root.addArrangedSubview(mark)
        root.addArrangedSubview(title)
        root.addArrangedSubview(subtitle)
        root.addArrangedSubview(status)
        root.addArrangedSubview(action)
        mark.widthAnchor.constraint(equalToConstant: 42).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 42).isActive = true
        title.heightAnchor.constraint(equalToConstant: 34).isActive = true
        subtitle.heightAnchor.constraint(equalToConstant: 22).isActive = true
        status.heightAnchor.constraint(equalToConstant: 24).isActive = true
        action.widthAnchor.constraint(equalToConstant: 116).isActive = true
        action.heightAnchor.constraint(equalToConstant: 40).isActive = true
        root.setCustomSpacing(10, after: mark)
        root.setCustomSpacing(3, after: title)
        root.setCustomSpacing(14, after: subtitle)
        root.setCustomSpacing(18, after: status)

        UIView.animate(withDuration: 0.2) {
            mark.alpha = 1
            title.alpha = 1
            subtitle.alpha = 1
            status.alpha = 1
        }
        fetchStartupConfig()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [weak self] in
            guard let self = self else { return }
            self.splashReady = true
            self.advanceLaunchGate()
        }
    }

    @objc private func retryLaunch() {
        fetchStartupConfig()
    }

    private func fetchStartupConfig() {
        launchAction?.isHidden = true
        launchStatus?.text = "正在连接管理后台"
        startupResolved = false
        launchFlowStarted = false
        launchGateCompleted = false
        AppConfigClient.fetch { [weak self] result in
            guard let self = self, self.view.window != nil else { return }
            self.pendingStartupConfig = result
            self.startupResolved = true
            self.advanceLaunchGate()
        }
    }

    private func advanceLaunchGate() {
        guard splashReady, startupResolved, !launchFlowStarted, !launchGateCompleted, !homeShown else { return }
        launchFlowStarted = true
        guard let result = pendingStartupConfig else { return }
        if result.authorizationRejected {
            launchStatus?.text = result.errorMessage ?? "管理后台验证失败"
            launchAction?.isHidden = false
            return
        }
        guard let config = result.config else {
            launchStatus?.text = result.errorMessage ?? "管理后台暂不可用"
            launchAction?.isHidden = false
            return
        }
        if result.fromCache {
            launchStatus?.text = result.errorMessage.map { "网络异常，使用本地配置：\($0)" } ?? "网络异常，使用本地配置"
        }
        let belowMinimum = compareVersions(Theme.appVersion, config.minimumVersion) < 0
        let hasNewVersion = compareVersions(Theme.appVersion, config.latestVersion) < 0
        if belowMinimum || (config.updateMode == 2 && hasNewVersion) {
            showLaunchUpdate(config, forced: true) { [weak self] in
                self?.showLaunchNotice(config) { self?.completeLaunchGate(result) }
            }
        } else if config.updateMode == 1 && hasNewVersion {
            showLaunchUpdate(config, forced: false) { [weak self] in
                self?.showLaunchNotice(config) { self?.completeLaunchGate(result) }
            }
        } else {
            showLaunchNotice(config) { [weak self] in
                self?.completeLaunchGate(result)
            }
        }
    }

    private func compareVersions(_ current: String, _ target: String) -> Int {
        if target.isEmpty { return 0 }
        let left = current.components(separatedBy: CharacterSet(charactersIn: ".-_")).map { Int($0) ?? 0 }
        let right = target.components(separatedBy: CharacterSet(charactersIn: ".-_")).map { Int($0) ?? 0 }
        let length = max(left.count, right.count)
        for index in 0..<length {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a < b ? -1 : 1 }
        }
        return 0
    }

    private func showLaunchUpdate(_ config: StartupConfig, forced: Bool, afterDismiss: (() -> Void)?) {
        let missingUrl = config.downloadApk.isEmpty
        let card = cardView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22)
        ])

        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 10
        header.addArrangedSubview(brandMark(size: 32, fontSize: 16, radius: 7))
        let title = UILabel()
        title.text = missingUrl ? "更新配置异常" : (forced ? "需要更新" : "发现新版本")
        title.font = .boldSystemFont(ofSize: 17)
        title.textColor = Theme.textPrimary
        header.addArrangedSubview(title)
        header.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stack.addArrangedSubview(header)

        let goldLine = UILabel()
        goldLine.text = missingUrl ? "后台未提供可用的安装包地址" : "发现新版本 \(config.latestVersion)，建议及时更新"
        goldLine.font = .systemFont(ofSize: 11)
        goldLine.textColor = Theme.gold
        goldLine.numberOfLines = 0
        stack.addArrangedSubview(goldLine)
        stack.setCustomSpacing(6, after: header)

        let divider = UIView()
        divider.backgroundColor = Theme.border
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stack.addArrangedSubview(divider)
        stack.setCustomSpacing(14, after: goldLine)

        let desc = UILabel()
        desc.text = missingUrl ? "请联系管理员完善下载配置后重试。" : (config.updateDescription.isEmpty ? "更新包含稳定性和体验优化。" : config.updateDescription)
        desc.font = .systemFont(ofSize: 13)
        desc.textColor = Theme.textSecond
        desc.numberOfLines = 0
        stack.addArrangedSubview(desc)
        stack.setCustomSpacing(12, after: divider)

        let actions = UIStackView()
        actions.axis = .horizontal
        actions.spacing = 6
        actions.distribution = .fillEqually
        actions.heightAnchor.constraint(equalToConstant: 42).isActive = true
        stack.addArrangedSubview(actions)

        let modal = ModalController(content: card)
        if !forced && !missingUrl {
            let skip = actionButton("暂不更新", primary: false)
            skip.addAction(UIAction { _ in
                afterDismiss?()
                modal.dismiss(animated: false)
            }, for: .touchUpInside)
            actions.addArrangedSubview(skip)
        }
        let primary = actionButton(missingUrl ? "重新验证" : "立即更新", primary: true)
        primary.addAction(UIAction { _ in
            modal.dismiss(animated: false) { [weak self] in
                guard let self = self else { return }
                if missingUrl {
                    self.fetchStartupConfig()
                } else {
                    afterDismiss?()
                    self.startUpdateDownload(config.downloadApk)
                }
            }
        }, for: .touchUpInside)
        actions.addArrangedSubview(primary)
        present(modal, animated: false)
    }

    private func showLaunchNotice(_ config: StartupConfig, afterDismiss: @escaping () -> Void) {
        if !config.noticeOpen || !canShowNotice(config) {
            afterDismiss()
            return
        }
        let card = cardView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22)
        ])

        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 10
        header.addArrangedSubview(brandMark(size: 34, fontSize: 17, radius: 7))
        let sysLabel = UILabel()
        sysLabel.text = "系统公告"
        sysLabel.font = .boldSystemFont(ofSize: 11)
        sysLabel.textColor = Theme.gold
        header.addArrangedSubview(sysLabel)
        let spacer = UIView()
        header.addArrangedSubview(spacer)
        let important = UILabel()
        important.text = " 重要通知"
        important.font = .systemFont(ofSize: 10)
        important.textColor = Theme.green
        header.addArrangedSubview(important)
        header.heightAnchor.constraint(equalToConstant: 34).isActive = true
        stack.addArrangedSubview(header)

        let noticeTitle = UILabel()
        noticeTitle.text = config.noticeTitle.isEmpty ? "公告" : config.noticeTitle
        noticeTitle.font = .boldSystemFont(ofSize: 19)
        noticeTitle.textColor = Theme.textPrimary
        noticeTitle.numberOfLines = 0
        stack.addArrangedSubview(noticeTitle)
        stack.setCustomSpacing(4, after: header)

        let underline = UIView()
        underline.backgroundColor = Theme.gold
        underline.widthAnchor.constraint(equalToConstant: 38).isActive = true
        underline.heightAnchor.constraint(equalToConstant: 2).isActive = true
        stack.addArrangedSubview(underline)
        stack.setCustomSpacing(14, after: noticeTitle)

        let bodyScroll = UIScrollView()
        bodyScroll.translatesAutoresizingMaskIntoConstraints = false
        bodyScroll.showsVerticalScrollIndicator = true
        bodyScroll.heightAnchor.constraint(equalToConstant: 160).isActive = true
        let body = UILabel()
        body.text = config.noticeContent
        body.font = .systemFont(ofSize: 13)
        body.textColor = Theme.textSecond
        body.numberOfLines = 0
        body.translatesAutoresizingMaskIntoConstraints = false
        bodyScroll.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.topAnchor),
            body.bottomAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.bottomAnchor),
            body.leadingAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: bodyScroll.contentLayoutGuide.trailingAnchor),
            body.widthAnchor.constraint(equalTo: bodyScroll.frameLayoutGuide.widthAnchor)
        ])
        stack.addArrangedSubview(bodyScroll)
        stack.setCustomSpacing(6, after: underline)

        let divider = UIView()
        divider.backgroundColor = Theme.border
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stack.addArrangedSubview(divider)
        stack.setCustomSpacing(14, after: bodyScroll)

        let button = actionButton(config.noticeLink.isEmpty ? "知道了" : (config.noticeButton.isEmpty ? "查看详情" : config.noticeButton), primary: true)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(button)

        let modal = ModalController(content: card)
        button.addAction(UIAction { _ in
            if !config.noticeLink.isEmpty {
                self.openExternalUrl(config.noticeLink)
            }
            modal.dismiss(animated: false, completion: afterDismiss)
        }, for: .touchUpInside)
        present(modal, animated: false) {
            self.recordNoticeShown(config)
        }
    }

    private func noticeState(_ config: StartupConfig) -> (key: String, day: String, used: Int) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        let today = formatter.string(from: Date())
        let content = Theme.appVersion + "\u{0}" + config.noticeTitle + "\u{0}" + config.noticeContent + "\u{0}" + config.noticeLink
        let key = String(javaHash(content))
        let prefs = UserDefaults.standard
        let same = prefs.string(forKey: "startup_notice_key") == key
        let day = prefs.string(forKey: "startup_notice_day") ?? ""
        let used = (same && day == today) ? prefs.integer(forKey: "startup_notice_count") : 0
        return (key, today, used)
    }

    private func canShowNotice(_ config: StartupConfig) -> Bool {
        return config.noticeOpen
    }

    private func recordNoticeShown(_ config: StartupConfig) {
        let state = noticeState(config)
        UserDefaults.standard.set(state.key, forKey: "startup_notice_key")
        UserDefaults.standard.set(state.day, forKey: "startup_notice_day")
        UserDefaults.standard.set(state.used + 1, forKey: "startup_notice_count")
    }

    private func javaHash(_ s: String) -> Int {
        var h = 0
        for b in s.utf8 {
            h = h &* 31 &+ Int(b)
        }
        return h
    }

    private func completeLaunchGate(_ result: StartupConfigResult) {
        guard !homeShown, !launchGateCompleted else { return }
        launchGateCompleted = true
        launchStatus?.text = result.fromCache ? "已使用本地启动配置" : "启动配置已完成"
        enterHome(result)
    }

    private func enterHome(_ result: StartupConfigResult) {
        guard !homeShown else { return }
        homeShown = true
        buildHomeScreen()
        renderStatus(result.fromCache ? "  已使用本地启动配置    v\(Theme.appVersion)" : "  启动配置已同步    v\(Theme.appVersion)")
    }

    // MARK: - Home + About UI

    private func buildHomeScreen() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let root = UIStackView()
        root.axis = .vertical
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        let pageContainer = UIView()
        pageContainer.translatesAutoresizingMaskIntoConstraints = false

        let homeScrollView = UIScrollView()
        homeScrollView.translatesAutoresizingMaskIntoConstraints = false
        homeScrollView.showsVerticalScrollIndicator = false
        let homeContent = buildHomeContent()
        homeContent.translatesAutoresizingMaskIntoConstraints = false
        homeScrollView.addSubview(homeContent)
        NSLayoutConstraint.activate([
            homeContent.topAnchor.constraint(equalTo: homeScrollView.contentLayoutGuide.topAnchor, constant: 8),
            homeContent.bottomAnchor.constraint(equalTo: homeScrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            homeContent.leadingAnchor.constraint(equalTo: homeScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            homeContent.trailingAnchor.constraint(equalTo: homeScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            homeContent.widthAnchor.constraint(equalTo: homeScrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        homeScroll = homeScrollView

        let aboutScrollView = UIScrollView()
        aboutScrollView.translatesAutoresizingMaskIntoConstraints = false
        aboutScrollView.showsVerticalScrollIndicator = false
        let aboutContent = buildAboutContent()
        aboutContent.translatesAutoresizingMaskIntoConstraints = false
        aboutScrollView.addSubview(aboutContent)
        NSLayoutConstraint.activate([
            aboutContent.topAnchor.constraint(equalTo: aboutScrollView.contentLayoutGuide.topAnchor, constant: 10),
            aboutContent.bottomAnchor.constraint(equalTo: aboutScrollView.contentLayoutGuide.bottomAnchor, constant: -14),
            aboutContent.leadingAnchor.constraint(equalTo: aboutScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            aboutContent.trailingAnchor.constraint(equalTo: aboutScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            aboutContent.widthAnchor.constraint(equalTo: aboutScrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        aboutScroll = aboutScrollView
        aboutScrollView.isHidden = true

        pageContainer.addSubview(homeScrollView)
        pageContainer.addSubview(aboutScrollView)
        NSLayoutConstraint.activate([
            homeScrollView.topAnchor.constraint(equalTo: pageContainer.topAnchor),
            homeScrollView.bottomAnchor.constraint(equalTo: pageContainer.bottomAnchor),
            homeScrollView.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor),
            homeScrollView.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor),
            aboutScrollView.topAnchor.constraint(equalTo: pageContainer.topAnchor),
            aboutScrollView.bottomAnchor.constraint(equalTo: pageContainer.bottomAnchor),
            aboutScrollView.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor),
            aboutScrollView.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor)
        ])

        let navDivider = UIView()
        navDivider.backgroundColor = Theme.border
        navDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let nav = UIStackView()
        nav.axis = .horizontal
        nav.distribution = .fillEqually
        nav.backgroundColor = Theme.cardHeader
        nav.heightAnchor.constraint(equalToConstant: 50).isActive = true
        homeTab = NavButton(icon: "⌂", label: "主页", selected: true)
        aboutTab = NavButton(icon: "ⓘ", label: "关于", selected: false)
        homeTab?.addTarget(self, action: #selector(homeTabTapped), for: .touchUpInside)
        aboutTab?.addTarget(self, action: #selector(aboutTabTapped), for: .touchUpInside)
        nav.addArrangedSubview(homeTab!)
        nav.addArrangedSubview(aboutTab!)

        root.addArrangedSubview(pageContainer)
        root.addArrangedSubview(navDivider)
        root.addArrangedSubview(nav)
        selectTab(selectedHome)
    }

    private func buildHomeContent() -> UIStackView {
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 12

        let topBar = UIStackView()
        topBar.axis = .horizontal
        topBar.alignment = .center
        topBar.spacing = 10
        topBar.addArrangedSubview(brandMark(size: 34, fontSize: 17, radius: 7))
        let topTexts = UIStackView()
        topTexts.axis = .vertical
        let appTitle = UILabel()
        appTitle.text = "王者共享"
        appTitle.font = .boldSystemFont(ofSize: 16)
        appTitle.textColor = Theme.textPrimary
        let appSub = UILabel()
        appSub.text = "实时对局战术地图  v\(Theme.appVersion)"
        appSub.font = .systemFont(ofSize: 10)
        appSub.textColor = Theme.textSecond
        topTexts.addArrangedSubview(appTitle)
        topTexts.addArrangedSubview(appSub)
        topBar.addArrangedSubview(topTexts)
        content.addArrangedSubview(topBar)

        let statusContainer = UIView()
        statusContainer.backgroundColor = Theme.fieldBg
        statusContainer.layer.cornerRadius = 7
        statusContainer.layer.borderWidth = 1
        statusContainer.layer.borderColor = Theme.border.cgColor
        statusContainer.clipsToBounds = true
        statusContainer.heightAnchor.constraint(equalToConstant: 36).isActive = true
        let statusStrip = UILabel()
        statusStrip.font = .systemFont(ofSize: 12)
        statusStrip.textColor = Theme.textSecond
        statusStrip.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(statusStrip)
        NSLayoutConstraint.activate([
            statusStrip.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor, constant: 12),
            statusStrip.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: -12),
            statusStrip.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor)
        ])
        statusStripLabel = statusStrip
        content.addArrangedSubview(statusContainer)
        renderStatus("  准备连接共享房间")

        let connectCard = cardView(radius: 10)
        let connectStack = UIStackView()
        connectStack.axis = .vertical
        connectStack.translatesAutoresizingMaskIntoConstraints = false
        connectCard.addSubview(connectStack)
        NSLayoutConstraint.activate([
            connectStack.topAnchor.constraint(equalTo: connectCard.topAnchor, constant: 14),
            connectStack.bottomAnchor.constraint(equalTo: connectCard.bottomAnchor, constant: -14),
            connectStack.leadingAnchor.constraint(equalTo: connectCard.leadingAnchor, constant: 14),
            connectStack.trailingAnchor.constraint(equalTo: connectCard.trailingAnchor, constant: -14)
        ])
        let connectTitle = UILabel()
        connectTitle.text = "连接房间"
        connectTitle.font = .boldSystemFont(ofSize: 14)
        connectTitle.textColor = Theme.textPrimary
        let connectSub = UILabel()
        connectSub.text = "输入房间号后开始共享"
        connectSub.font = .systemFont(ofSize: 11)
        connectSub.textColor = Theme.textSecond
        let field = UITextField()
        field.placeholder = "请输入房间号"
        field.attributedPlaceholder = NSAttributedString(string: "请输入房间号", attributes: [.foregroundColor: Theme.textSecond])
        field.textColor = Theme.textPrimary
        field.font = .systemFont(ofSize: 15)
        field.backgroundColor = Theme.fieldBg
        field.layer.cornerRadius = 6
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.border.cgColor
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 11, height: 1))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 11, height: 1))
        field.rightViewMode = .always
        field.text = AppPrefs.shared.room
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        roomField = field
        let connect = styledButton("连接并开启绘制", "primary")
        connect.heightAnchor.constraint(equalToConstant: 44).isActive = true
        connect.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        connectButton = connect
        connectStack.addArrangedSubview(connectTitle)
        connectStack.addArrangedSubview(connectSub)
        connectStack.setCustomSpacing(12, after: connectSub)
        connectStack.addArrangedSubview(field)
        connectStack.setCustomSpacing(12, after: field)
        connectStack.addArrangedSubview(connect)
        content.addArrangedSubview(connectCard)

        let actions = UIStackView()
        actions.axis = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 6
        actions.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let settings = styledButton("悬浮设置", "outline")
        settings.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        let stop = styledButton("关闭绘制", "danger")
        stop.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        actions.addArrangedSubview(settings)
        actions.addArrangedSubview(stop)
        content.addArrangedSubview(actions)

        let securityCard = cardView()
        let securityStack = UIStackView()
        securityStack.axis = .horizontal
        securityStack.alignment = .center
        securityStack.translatesAutoresizingMaskIntoConstraints = false
        securityCard.addSubview(securityStack)
        NSLayoutConstraint.activate([
            securityStack.topAnchor.constraint(equalTo: securityCard.topAnchor, constant: 16),
            securityStack.bottomAnchor.constraint(equalTo: securityCard.bottomAnchor, constant: -16),
            securityStack.leadingAnchor.constraint(equalTo: securityCard.leadingAnchor, constant: 16),
            securityStack.trailingAnchor.constraint(equalTo: securityCard.trailingAnchor, constant: -16)
        ])
        let securityTitles = UIStackView()
        securityTitles.axis = .vertical
        let securityTitle = UILabel()
        securityTitle.text = "悬浮窗安全保护"
        securityTitle.font = .boldSystemFont(ofSize: 14)
        securityTitle.textColor = Theme.textPrimary
        let securityStatus = UILabel()
        securityStatus.font = .systemFont(ofSize: 11)
        securityStatus.textColor = Theme.textSecond
        securityTitles.addArrangedSubview(securityTitle)
        securityTitles.addArrangedSubview(securityStatus)
        let securitySwitch = UISwitch()
        securitySwitch.isOn = AppPrefs.shared.secureOverlay
        securitySwitch.onTintColor = Theme.green
        securitySwitch.addTarget(self, action: #selector(securityChanged(_:)), for: .valueChanged)
        securityStack.addArrangedSubview(securityTitles)
        securityStack.addArrangedSubview(securitySwitch)
        securityStatusLabel = securityStatus
        updateSecurityStatus()
        content.addArrangedSubview(securityCard)

        let site = styledButton("打开网站", "outline")
        site.heightAnchor.constraint(equalToConstant: 44).isActive = true
        site.addTarget(self, action: #selector(openWebsite), for: .touchUpInside)
        content.addArrangedSubview(site)
        return content
    }

    private func buildAboutContent() -> UIStackView {
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 12

        let aboutCard = cardView()
        let aboutStack = UIStackView()
        aboutStack.axis = .vertical
        aboutStack.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.addSubview(aboutStack)
        NSLayoutConstraint.activate([
            aboutStack.topAnchor.constraint(equalTo: aboutCard.topAnchor, constant: 16),
            aboutStack.bottomAnchor.constraint(equalTo: aboutCard.bottomAnchor, constant: -16),
            aboutStack.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 16),
            aboutStack.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -16)
        ])
        let aboutTitle = UILabel()
        aboutTitle.text = "关于"
        aboutTitle.font = .boldSystemFont(ofSize: 16)
        aboutTitle.textColor = Theme.textPrimary
        let version = UILabel()
        version.text = "王者共享 v\(Theme.appVersion)"
        version.font = .systemFont(ofSize: 12)
        version.textColor = Theme.textSecond
        let tagline = UILabel()
        tagline.text = "轻量稳定的实时地图共享客户端"
        tagline.font = .systemFont(ofSize: 11)
        tagline.textColor = Theme.textSecond
        aboutStack.addArrangedSubview(aboutTitle)
        aboutStack.setCustomSpacing(4, after: aboutTitle)
        aboutStack.addArrangedSubview(version)
        aboutStack.setCustomSpacing(2, after: version)
        aboutStack.addArrangedSubview(tagline)
        content.addArrangedSubview(aboutCard)

        let infoCard = cardView()
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoCard.addSubview(infoStack)
        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 16),
            infoStack.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -16),
            infoStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -16)
        ])
        let infoTitle = UILabel()
        infoTitle.text = "服务信息"
        infoTitle.font = .boldSystemFont(ofSize: 14)
        infoTitle.textColor = Theme.textPrimary
        let domain = UILabel()
        domain.text = "king.weilua.top"
        domain.font = .systemFont(ofSize: 11)
        domain.textColor = Theme.textSecond
        infoStack.addArrangedSubview(infoTitle)
        infoStack.setCustomSpacing(6, after: infoTitle)
        infoStack.addArrangedSubview(domain)
        content.addArrangedSubview(infoCard)

        let thanksCard = cardView()
        let thanksStack = UIStackView()
        thanksStack.axis = .vertical
        thanksStack.spacing = 6
        thanksStack.translatesAutoresizingMaskIntoConstraints = false
        thanksCard.addSubview(thanksStack)
        NSLayoutConstraint.activate([
            thanksStack.topAnchor.constraint(equalTo: thanksCard.topAnchor, constant: 16),
            thanksStack.bottomAnchor.constraint(equalTo: thanksCard.bottomAnchor, constant: -16),
            thanksStack.leadingAnchor.constraint(equalTo: thanksCard.leadingAnchor, constant: 16),
            thanksStack.trailingAnchor.constraint(equalTo: thanksCard.trailingAnchor, constant: -16)
        ])
        let thanksHeader = UIStackView()
        thanksHeader.axis = .horizontal
        thanksHeader.alignment = .center
        let thanksTitle = UILabel()
        thanksTitle.text = "鸣谢"
        thanksTitle.font = .boldSystemFont(ofSize: 14)
        thanksTitle.textColor = Theme.textPrimary
        let count = UILabel()
        count.text = "\(contributors.count)位"
        count.font = .systemFont(ofSize: 12)
        count.textColor = Theme.gold
        thanksHeader.addArrangedSubview(thanksTitle)
        let headerSpacer = UIView()
        thanksHeader.addArrangedSubview(headerSpacer)
        thanksHeader.addArrangedSubview(count)
        thanksStack.addArrangedSubview(thanksHeader)
        thanksStack.setCustomSpacing(8, after: thanksHeader)

        let columns = UIScreen.main.bounds.width >= 420 ? 5 : 4
        var remaining = contributors
        while !remaining.isEmpty {
            let group = Array(remaining.prefix(columns))
            remaining = Array(remaining.dropFirst(columns))
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 5
            row.heightAnchor.constraint(equalToConstant: 64).isActive = true
            for contributor in group {
                row.addArrangedSubview(contributorCell(contributor))
            }
            for _ in 0..<(columns - group.count) {
                row.addArrangedSubview(UIView())
            }
            thanksStack.addArrangedSubview(row)
        }
        content.addArrangedSubview(thanksCard)
        return content
    }

    private func contributorCell(_ contributor: Contributor) -> UIView {
        let cell = UIView()
        let avatarBox = UIView()
        avatarBox.translatesAutoresizingMaskIntoConstraints = false
        let avatarLabel = UILabel()
        avatarLabel.text = String(contributor.name.prefix(1))
        avatarLabel.font = .boldSystemFont(ofSize: 13)
        avatarLabel.textColor = Theme.textPrimary
        avatarLabel.textAlignment = .center
        avatarLabel.backgroundColor = Theme.cardBg
        avatarLabel.layer.cornerRadius = 17
        avatarLabel.layer.borderWidth = 1
        avatarLabel.layer.borderColor = Theme.borderLight.cgColor
        avatarLabel.clipsToBounds = true
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        let avatarImage = UIImageView()
        avatarImage.contentMode = .scaleAspectFill
        avatarImage.layer.cornerRadius = 17
        avatarImage.clipsToBounds = true
        avatarImage.isHidden = true
        avatarImage.translatesAutoresizingMaskIntoConstraints = false
        let name = UILabel()
        name.text = contributor.name
        name.font = .boldSystemFont(ofSize: 10)
        name.textColor = Theme.textPrimary
        name.textAlignment = .center
        name.lineBreakMode = .byTruncatingTail
        name.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(avatarBox)
        avatarBox.addSubview(avatarLabel)
        avatarBox.addSubview(avatarImage)
        cell.addSubview(name)
        NSLayoutConstraint.activate([
            avatarBox.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            avatarBox.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            avatarBox.widthAnchor.constraint(equalToConstant: 34),
            avatarBox.heightAnchor.constraint(equalToConstant: 34),
            avatarLabel.topAnchor.constraint(equalTo: avatarBox.topAnchor),
            avatarLabel.bottomAnchor.constraint(equalTo: avatarBox.bottomAnchor),
            avatarLabel.leadingAnchor.constraint(equalTo: avatarBox.leadingAnchor),
            avatarLabel.trailingAnchor.constraint(equalTo: avatarBox.trailingAnchor),
            avatarImage.topAnchor.constraint(equalTo: avatarBox.topAnchor),
            avatarImage.bottomAnchor.constraint(equalTo: avatarBox.bottomAnchor),
            avatarImage.leadingAnchor.constraint(equalTo: avatarBox.leadingAnchor),
            avatarImage.trailingAnchor.constraint(equalTo: avatarBox.trailingAnchor),
            name.topAnchor.constraint(equalTo: avatarBox.bottomAnchor, constant: 2),
            name.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            name.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            name.heightAnchor.constraint(equalToConstant: 15)
        ])
        QqAvatarLoader.shared.load(qq: contributor.qq) { image in
            if let image = image, avatarImage.window != nil {
                avatarImage.image = image
                avatarImage.isHidden = false
                avatarLabel.isHidden = true
            }
        }
        return cell
    }

    // MARK: - Helpers

    private func brandMark(size: CGFloat, fontSize: CGFloat, radius: CGFloat) -> UILabel {
        let label = UILabel()
        label.text = "王"
        label.font = .boldSystemFont(ofSize: fontSize)
        label.textColor = Theme.gold
        label.textAlignment = .center
        label.backgroundColor = Theme.markBg
        label.layer.cornerRadius = radius
        label.layer.borderWidth = 1
        label.layer.borderColor = Theme.markBorder.cgColor
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: size),
            label.heightAnchor.constraint(equalToConstant: size)
        ])
        return label
    }

    private func cardView(radius: CGFloat = 14) -> UIView {
        let v = UIView()
        v.styleCard(fill: Theme.cardBg, radius: radius, stroke: Theme.border)
        return v
    }

    private func actionButton(_ label: String, primary: Bool) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(label, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 12)
        b.layer.cornerRadius = 7
        b.clipsToBounds = true
        if primary {
            b.setTitleColor(Theme.markBg, for: .normal)
            b.backgroundColor = Theme.gold
        } else {
            b.setTitleColor(Theme.textPrimary, for: .normal)
            b.backgroundColor = Theme.cardHeader
            b.layer.borderWidth = 1
            b.layer.borderColor = Theme.borderLight.cgColor
        }
        return b
    }

    private func styledButton(_ label: String, _ style: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(label, for: .normal)
        b.titleLabel?.font = .boldSystemFont(ofSize: 13)
        b.layer.cornerRadius = 6
        b.clipsToBounds = true
        switch style {
        case "primary":
            b.setTitleColor(Theme.markBg, for: .normal)
            b.backgroundColor = Theme.gold
        case "danger":
            b.setTitleColor(Theme.red, for: .normal)
            b.backgroundColor = Theme.cardBg
            b.layer.borderWidth = 1
            b.layer.borderColor = Theme.red.cgColor
        default:
            b.setTitleColor(Theme.textPrimary, for: .normal)
            b.backgroundColor = Theme.cardBg
            b.layer.borderWidth = 1
            b.layer.borderColor = Theme.borderLight.cgColor
        }
        return b
    }

    private func renderStatus(_ raw: String) {
        guard let label = statusStripLabel else {
            launchStatus?.text = raw
            return
        }
        if raw.hasPrefix("") {
            let attr = NSMutableAttributedString(string: raw)
            attr.addAttribute(.foregroundColor, value: Theme.gold, range: NSRange(location: 0, length: 1))
            attr.addAttribute(.foregroundColor, value: Theme.textSecond, range: NSRange(location: 1, length: raw.count - 1))
            label.attributedText = attr
        } else {
            label.text = raw
        }
    }

    private func updateSecurityStatus() {
        securityStatusLabel?.text = AppPrefs.shared.secureOverlay ? "已开启  防截图 / 防录屏" : "已关闭  允许系统捕获"
    }

    private func selectTab(_ home: Bool) {
        selectedHome = home
        homeScroll?.isHidden = !home
        aboutScroll?.isHidden = home
        homeTab?.selected = home
        aboutTab?.selected = !home
    }

    private func openExternalUrl(_ url: String) {
        guard let u = URL(string: url) else { return }
        UIApplication.shared.open(u, options: [:], completionHandler: nil)
    }

    private func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }

    // MARK: - Actions

    @objc private func homeTabTapped() { selectTab(true) }
    @objc private func aboutTabTapped() { selectTab(false) }

    @objc private func connectTapped() {
        startOverlay()
    }

    @objc private func settingsTapped() {
        SettingsWindow.shared.show()
    }

    @objc private func stopTapped() {
        OverlaySession.shared.stop()
        renderStatus("绘制已关闭")
    }

    @objc private func openWebsite() {
        openExternalUrl(Theme.websiteURL)
    }

    @objc private func securityChanged(_ sender: UISwitch) {
        AppPrefs.shared.secureOverlay = sender.isOn
        updateSecurityStatus()
        OverlaySession.shared.securityChanged()
        SettingsWindow.shared.securityChanged()
    }

    private func startOverlay() {
        guard !roomProbeInFlight else { return }
        let room = (roomField?.text ?? "").trimmingCharacters(in: .whitespaces)
        if room.isEmpty {
            renderStatus("  请输入房间号")
            roomField?.layer.borderColor = Theme.red.cgColor
            return
        }
        if room.count > 128 || room.contains("[==]") || room.contains("#") || room.contains("\n") || room.contains("\r") {
            renderStatus("  房间号格式不正确")
            roomField?.layer.borderColor = Theme.red.cgColor
            return
        }
        roomField?.layer.borderColor = Theme.border.cgColor
        roomProbeInFlight = true
        connectButton?.isEnabled = false
        connectButton?.alpha = 0.62
        renderStatus("  正在检查房间 \(room)")
        RoomWebSocket.probe(room: room) { [weak self] exists in
            guard let self = self else { return }
            self.roomProbeInFlight = false
            self.connectButton?.isEnabled = true
            self.connectButton?.alpha = 1
            if !exists {
                self.renderStatus("  房间 \(room) 不存在或暂未上线")
                return
            }
            AppPrefs.shared.room = room
            OverlaySession.shared.connect(room: room)
            SettingsWindow.shared.show()
            self.renderStatus("  正在连接房间 \(room)")
        }
    }

    // MARK: - Update download

    private func startUpdateDownload(_ url: String) {
        guard downloadTask == nil else { return }
        guard let u = URL(string: url), let scheme = u.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            launchStatus?.text = "更新地址无效"
            return
        }
        downloadFinished = false
        let card = buildDownloadCard()
        let modal = ModalController(content: card)
        downloadDialog = modal
        present(modal, animated: false)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        downloadSession = session
        downloadTask = session.downloadTask(with: u)
        downloadTask?.resume()
    }

    private func buildDownloadCard() -> UIView {
        let card = cardView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22)
        ])

        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 10
        header.addArrangedSubview(brandMark(size: 32, fontSize: 16, radius: 7))
        let title = UILabel()
        title.text = "正在下载更新"
        title.font = .boldSystemFont(ofSize: 17)
        title.textColor = Theme.textPrimary
        header.addArrangedSubview(title)
        header.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stack.addArrangedSubview(header)

        let state = UILabel()
        state.text = "正在连接下载服务器"
        state.font = .systemFont(ofSize: 11)
        state.textColor = Theme.gold
        stack.addArrangedSubview(state)
        stack.setCustomSpacing(6, after: header)

        let divider = UIView()
        divider.backgroundColor = Theme.border
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stack.addArrangedSubview(divider)
        stack.setCustomSpacing(20, after: state)

        let progress = UIProgressView()
        progress.progressTintColor = Theme.gold
        progress.trackTintColor = Theme.border
        progress.heightAnchor.constraint(equalToConstant: 12).isActive = true
        downloadProgress = progress
        stack.addArrangedSubview(progress)

        let progressRow = UIStackView()
        progressRow.axis = .horizontal
        progressRow.alignment = .center
        let percent = UILabel()
        percent.text = "0%"
        percent.font = .boldSystemFont(ofSize: 22)
        percent.textColor = Theme.textPrimary
        let size = UILabel()
        size.text = "准备中"
        size.font = .systemFont(ofSize: 11)
        size.textColor = Theme.textSecond
        size.textAlignment = .right
        progressRow.addArrangedSubview(percent)
        progressRow.addArrangedSubview(size)
        progressRow.heightAnchor.constraint(equalToConstant: 36).isActive = true
        percent.widthAnchor.constraint(equalToConstant: 65).isActive = true
        downloadPercent = percent
        downloadSize = size
        stack.addArrangedSubview(progressRow)
        stack.setCustomSpacing(8, after: progress)

        let cancel = actionButton("取消下载", primary: false)
        cancel.heightAnchor.constraint(equalToConstant: 42).isActive = true
        cancel.addAction(UIAction { [weak self] _ in
            self?.cancelUpdateDownload()
        }, for: .touchUpInside)
        stack.addArrangedSubview(cancel)
        stack.setCustomSpacing(14, after: progressRow)
        return card
    }

    private func cancelUpdateDownload() {
        downloadFinished = true
        downloadTask?.cancel()
        downloadTask = nil
        downloadSession = nil
        downloadDialog?.dismiss(animated: false)
        downloadDialog = nil
        launchStatus?.text = "已取消更新下载"
        launchAction?.isHidden = false
    }

    private func finishDownload(success: Bool, fileURL: URL?, reason: String? = nil) {
        downloadTask = nil
        downloadSession = nil
        if !success {
            downloadDialog?.dismiss(animated: false)
            downloadDialog = nil
            launchStatus?.text = "更新下载失败：\(reason ?? "未知错误")"
            launchAction?.isHidden = false
            return
        }
        guard let fileURL = fileURL else {
            downloadDialog?.dismiss(animated: false)
            downloadDialog = nil
            launchStatus?.text = "安装包读取失败，请重新下载"
            launchAction?.isHidden = false
            return
        }
        downloadDialog?.dismiss(animated: false)
        downloadDialog = nil
        attemptTrollStoreInstall(fileURL)
    }

    private func attemptTrollStoreInstall(_ fileURL: URL) {
        let encoded = fileURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileURL.absoluteString
        let candidates = [
            "apple-magnifier://install?url=\(encoded)",
            "trollstore://install?url=\(encoded)"
        ]
        for candidate in candidates {
            if let u = URL(string: candidate), UIApplication.shared.canOpenURL(u) {
                UIApplication.shared.open(u, options: [:], completionHandler: nil)
                return
            }
        }
        let alert = UIAlertController(
            title: "更新已下载",
            message: "IPA 已保存到 文稿/hai-update.ipa，请打开巨魔商店导入安装",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

extension MainViewController: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let pct = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        downloadProgress?.progress = Float(pct)
        downloadPercent?.text = "\(Int(pct * 100))%"
        if totalBytesExpectedToWrite > 0 {
            downloadSize?.text = "\(formatSize(totalBytesWritten)) / \(formatSize(totalBytesExpectedToWrite))"
        } else {
            downloadSize?.text = "\(formatSize(totalBytesWritten)) / 计算中"
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard !downloadFinished else { return }
        downloadFinished = true
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            finishDownload(success: false, fileURL: nil, reason: "存储目录不可用")
            return
        }
        let destination = documents.appendingPathComponent("hai-update.ipa")
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            finishDownload(success: false, fileURL: nil, reason: error.localizedDescription)
            return
        }
        downloadSize?.text = "下载完成，正在打开安装器"
        finishDownload(success: true, fileURL: destination)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, !downloadFinished {
            downloadFinished = true
            finishDownload(success: false, fileURL: nil, reason: error.localizedDescription)
        }
    }
}

private final class NavButton: UIControl {
    private let iconLabel = UILabel()
    private let caption = UILabel()

    var selected: Bool = false {
        didSet {
            iconLabel.textColor = selected ? Theme.gold : Theme.mutedText
            caption.textColor = selected ? Theme.gold : Theme.mutedText
        }
    }

    init(icon: String, label: String, selected: Bool) {
        super.init(frame: .zero)
        iconLabel.text = icon
        iconLabel.font = .systemFont(ofSize: 18)
        iconLabel.textAlignment = .center
        caption.text = label
        caption.font = .systemFont(ofSize: 10)
        caption.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [iconLabel, caption])
        stack.axis = .vertical
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            iconLabel.heightAnchor.constraint(equalToConstant: 20),
            caption.heightAnchor.constraint(equalToConstant: 16)
        ])
        self.selected = selected
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}