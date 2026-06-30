import SwiftUI
import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let viewModel = UsageViewModel()
    private let languageStore = LanguageStore()
    private let launchAtLogin = LaunchAtLoginStore()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var pollingTask: Task<Void, Never>?
    private var shutdownHandler: (@Sendable () async -> Void)?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        shutdownHandler = viewModel.makeShutdownHandler()
        viewModel.onSnapshotChange = { [weak self] in
            self?.updateStatusItemImage()
        }

        configureStatusItem()
        configurePopover()
        launchAtLogin.refresh()

        pollingTask = Task { [viewModel] in
            await viewModel.runPollingLoop()
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageOnly
        updateStatusItemImage()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        let hosting = NSHostingController(rootView: UsagePopoverView(
            viewModel: viewModel,
            languageStore: languageStore,
            launchAtLogin: launchAtLogin
        ))
        // SwiftUI のレイアウトサイズを NSPopover の contentSize に反映させる。
        // これを設定しないと contentSize が既定の 320x320 のまま残り、NSPopover は
        // 320 を基準に位置決めしつつ実コンテンツ (約 500x420) を描画するため、
        // ウィンドウが上にずれて画面上端（メニューバー）にめり込み、ヘッダーが見切れる。
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
    }

    private func updateStatusItemImage() {
        guard let button = statusItem?.button else { return }
        if let image = MenuBarLabelRenderer.image(viewModel: viewModel) {
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = "TC"
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover(relativeTo: sender)
        }
    }

    private func showPopover(relativeTo button: NSStatusBarButton) {
        launchAtLogin.refresh()
        // AppKit に配置を任せる。NSPopover の裏側ウィンドウを setFrame で動かすと、
        // アローをアイコンに向けたままコンテンツだけがずれて見切れる（左に寄って途切れる）ため、
        // 手動センタリングは行わない。NSPopover は自動で画面内に収め、アローをアイコンに向ける。
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        let handler = MainActor.assumeIsolated { () -> (@Sendable () async -> Void)? in
            pollingTask?.cancel()
            return shutdownHandler
        }
        guard let handler else { return }
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            await handler()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2.0)
    }
}
