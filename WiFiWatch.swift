import Cocoa
import Network
import UserNotifications
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let pathMonitor = NWPathMonitor()
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 4
        cfg.timeoutIntervalForResource = 4
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    private var timer: Timer?
    private var isOnline: Bool?          // nil = unknown (just launched)
    private var failures = 0
    private var offlineSince: Date?
    private var paused = false
    private var notifyOnReconnect = UserDefaults.standard.object(forKey: "notifyOnReconnect") as? Bool ?? true

    private let statusLine = NSMenuItem(title: "Checking…", action: nil, keyEquivalent: "")
    private let pauseItem = NSMenuItem(title: "Pause Monitoring", action: #selector(togglePause), keyEquivalent: "p")
    private let reconnectItem = NSMenuItem(title: "Notify When Back Online", action: #selector(toggleReconnect), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        buildMenu()
        updateIcon()

        // React instantly to Wi-Fi changes, and poll for "connected but no internet".
        pathMonitor.pathUpdateHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.probe() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "path"))

        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.probe()
        }
        probe()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        [pauseItem, reconnectItem, loginItem].forEach { $0.target = self; menu.addItem($0) }
        reconnectItem.state = notifyOnReconnect ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit WiFiWatch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func togglePause() {
        paused.toggle()
        pauseItem.title = paused ? "Resume Monitoring" : "Pause Monitoring"
        if !paused { failures = 0; probe() }
        updateIcon()
    }

    @objc private func toggleReconnect() {
        notifyOnReconnect.toggle()
        UserDefaults.standard.set(notifyOnReconnect, forKey: "notifyOnReconnect")
        reconnectItem.state = notifyOnReconnect ? .on : .off
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Login item error: \(error)")
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - Connectivity check

    private func probe() {
        guard !paused else { return }
        var req = URLRequest(url: URL(string: "https://www.apple.com/library/test/success.html")!)
        req.httpMethod = "GET"
        session.dataTask(with: req) { [weak self] data, response, _ in
            var ok = false
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let data = data, let body = String(data: data, encoding: .utf8),
               body.contains("Success") {
                ok = true
            }
            DispatchQueue.main.async { self?.handle(ok: ok) }
        }.resume()
    }

    private func handle(ok: Bool) {
        guard !paused else { return }
        if ok {
            failures = 0
            let wasOnline = isOnline
            isOnline = true
            if wasOnline == false {
                if notifyOnReconnect {
                    var body = "Internet is working again."
                    if let since = offlineSince {
                        body += " (Down for \(format(Date().timeIntervalSince(since))))"
                    }
                    notify(title: "✅ Back online", body: body)
                }
                offlineSince = nil
            }
        } else {
            failures += 1
            // Two misses in a row (~5-10s) before crying wolf.
            if failures >= 2 && isOnline != false {
                isOnline = false
                offlineSince = Date()
                notify(title: "⚠️ Internet is down", body: "Your connection dropped. Check your hotspot.")
            }
        }
        updateIcon()
    }

    private func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
    }

    // MARK: - UI

    private func updateIcon() {
        let text: String
        if paused {
            text = "Paused"
        } else if isOnline == true {
            text = "Online"
        } else if isOnline == false {
            text = "Offline"
        } else {
            text = "Checking…"
        }
        statusItem.button?.image = nil
        statusItem.button?.title = "👀"
        statusLine.title = text
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // Show banners even though we're the "active" app.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
app.run()
