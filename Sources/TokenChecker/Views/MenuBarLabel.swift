import SwiftUI
import AppKit

/// メニューバーに表示する「サービス記号 + 2 段ミニバー」。
///
/// SwiftUI ビューを `ImageRenderer` で NSImage に焼いて、
/// `Image(nsImage:)` でメニューバーに渡す。
/// `MenuBarExtra` の label に SwiftUI ビューを直接渡すとフォント等が制限されるため。
struct MenuBarLabel: View {
    let viewModel: UsageViewModel

    var body: some View {
        if let image = MenuBarLabelRenderer.image(viewModel: viewModel) {
            Image(nsImage: image)
        } else {
            Text("TC")
        }
    }
}

enum MenuBarLabelRenderer {
    @MainActor
    static func image(viewModel: UsageViewModel) -> NSImage? {
        let content = HStack(spacing: 4) {
            MenuBarServiceUnit(
                symbolName: "sparkles",
                fiveHour: values(from: viewModel.snapshot.claude).fiveHour,
                weekly: values(from: viewModel.snapshot.claude).weekly
            )
            MenuBarServiceUnit(
                symbolName: "terminal.fill",
                fiveHour: values(from: viewModel.snapshot.codex).fiveHour,
                weekly: values(from: viewModel.snapshot.codex).weekly
            )
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
        .foregroundStyle(Color.primary)

        let renderer = ImageRenderer(content: content)
        // ビットマップは高 DPI で焼いておく．image.size には触らない
        // （触ると point 単位として誤認されて表示サイズまで縮んでしまう）．
        let maxScale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        renderer.scale = max(maxScale, 3)
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }

    private static func values(
        from result: Result<ServiceUsage, DomainError>?
    ) -> (fiveHour: Double?, weekly: Double?) {
        guard case .success(let usage) = result else {
            return (nil, nil)
        }
        return (usage.fiveHour?.utilization, usage.weekly?.utilization)
    }
}

private struct MenuBarServiceUnit: View {
    let symbolName: String
    let fiveHour: Double?
    let weekly: Double?

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Image(systemName: symbolName)
                .font(.system(size: 8.5, weight: .semibold))
                .frame(width: 9)
            VStack(spacing: 1.5) {
                MiniUsageBar(value: fiveHour)
                MiniUsageBar(value: weekly)
            }
        }
    }
}

private struct MiniUsageBar: View {
    let value: Double?

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.gray.opacity(0.3))
            if let value {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(UsageColor.color(for: value))
                        .frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
        }
        .frame(width: 18, height: 3)
    }
}
