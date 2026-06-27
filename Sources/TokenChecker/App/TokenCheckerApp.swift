import SwiftUI
import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let viewModel = UsageViewModel()
    private let languageStore = LanguageStore()
    private let launchAtLogin = LaunchAtLoginStore()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var pollingTask: Task<Void, Never>?
    private var shutdownHandler: (@Sendable () async -> Void)?
    private weak var anchorButton: NSStatusBarButton?

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
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: UsagePopoverView(
            viewModel: viewModel,
            languageStore: languageStore,
            launchAtLogin: launchAtLogin
        ))
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
        anchorButton = button
        launchAtLogin.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        centerPopover(relativeTo: button)
        DispatchQueue.main.async { [weak self, weak button] in
            guard let self, let button else { return }
            self.centerPopover(relativeTo: button)
        }
    }

    func popoverDidShow(_ notification: Notification) {
        guard let anchorButton else { return }
        centerPopover(relativeTo: anchorButton)
    }

    private func centerPopover(relativeTo button: NSStatusBarButton) {
        guard
            let popoverWindow = popover.contentViewController?.view.window,
            let buttonWindow = button.window
        else { return }

        let anchorFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visibleFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? anchorFrame
        let positioned = CenteredPopoverPositioner.positionedFrame(
            currentFrame: popoverWindow.frame,
            anchorFrame: anchorFrame,
            visibleFrame: visibleFrame
        )
        popoverWindow.setFrame(positioned, display: true)
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
