import SwiftUI
import AppKit

struct UsagePopoverView: View {
    @Bindable var viewModel: UsageViewModel
    @Bindable var languageStore: LanguageStore
    @ObservedObject var launchAtLogin: LaunchAtLoginStore
    @State private var showsSettings = false

    private var language: AppLanguage { languageStore.selectedLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            serviceCards
            footer
        }
        .padding(12)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Token Checker")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button {
                showsSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("settings.title", language: language))
            .popover(isPresented: $showsSettings, arrowEdge: .top) {
                settingsPopover
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("footer.refresh_now", language: language))
        }
    }

    private var serviceCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            ServiceCardView(
                brand: .claude,
                result: viewModel.snapshot.claude,
                language: language,
                loginAction: { viewModel.openClaudeLogin() }
            )

            ServiceCardView(
                brand: .codex,
                result: viewModel.snapshot.codex,
                language: language,
                loginAction: { viewModel.openCodexLogin() }
            )
        }
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("settings.title", language: language))
                .font(.system(size: 13, weight: .semibold))

            settingsRow(label: L10n.tr("settings.refresh_interval", language: language)) {
                Picker("", selection: $viewModel.pollingInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.label(language: language)).tag(interval)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            settingsRow(label: L10n.tr("settings.language", language: language)) {
                Picker("", selection: $languageStore.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(L10n.tr(option.displayKey, language: option)).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            settingsRow(label: L10n.tr("settings.launch_at_login", language: language)) {
                Toggle("", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { _ in launchAtLogin.toggle() }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
        .padding(12)
        .frame(width: 250)
    }

    private func settingsRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }

    private var footer: some View {
        HStack {
            if viewModel.snapshot.fetchedAt > .distantPast {
                Text(L10n.format(
                    "footer.updated_at",
                    language: language,
                    formattedTime(viewModel.snapshot.fetchedAt)
                ))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
            Spacer()
            Button(L10n.tr("footer.quit", language: language)) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct ServiceCardView: View {
    let brand: ServiceBrand
    let result: Result<ServiceUsage, DomainError>?
    let language: AppLanguage
    let loginAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
        }
        .padding(9)
        .serviceCardBackground(tint: backgroundTint)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: brand.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 14)
            Text(brand.title)
                .font(.system(size: 12, weight: .bold))
            Text(brand.subtitle)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch result {
        case .none:
            Text(L10n.tr("status.loading", language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        case .some(.success(let usage)):
            HStack(alignment: .top, spacing: 8) {
                LimitBlockView(
                    title: L10n.tr("window.five_hour", language: language),
                    noDataText: L10n.tr("window.five_hour.no_data", language: language),
                    limit: usage.fiveHour,
                    language: language,
                    showsWeeklyDots: false
                )
                LimitBlockView(
                    title: L10n.tr("window.weekly", language: language),
                    noDataText: L10n.tr("window.weekly.no_data", language: language),
                    limit: usage.weekly,
                    language: language,
                    showsWeeklyDots: true,
                    extraLimit: usage.weeklySonnet
                )
            }
        case .some(.failure(let error)):
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("error.fetch_failed", language: language))
                        .font(.system(size: 11, weight: .medium))
                    Text(error.localizedDescription(language: language))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Button {
                    loginAction()
                } label: {
                    Image(systemName: "person.badge.key")
                }
                .buttonStyle(.borderless)
                .help(L10n.format("service.login.help", language: language, brand.title))
            }
            .frame(minHeight: 54)
        }
    }

    private var statusColor: Color {
        switch result {
        case .some(.success):
            return .green
        case .some(.failure):
            return .orange
        case .none:
            return .secondary.opacity(0.5)
        }
    }

    private var backgroundTint: Color? {
        if case .some(.failure) = result { return .orange }
        return nil
    }
}

private struct LimitBlockView: View {
    let title: String
    let noDataText: String
    let limit: RateLimit?
    let language: AppLanguage
    let showsWeeklyDots: Bool
    var extraLimit: RateLimit?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let limit {
                let presentation = UsageLimitCellFormatter.presentation(
                    for: limit,
                    language: language
                )
                Text(labelText(presentation: presentation))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(presentation.percentText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(UsageColor.color(for: limit.utilization))
                    Spacer(minLength: 2)
                    Text(presentation.remainingText)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                ProgressBarView(value: limit.utilization, height: 5)

                if showsWeeklyDots {
                    WeekDotsView(fillFractions: WeeklyWindowSegments.fillFractions(resetsAt: limit.resetsAt))
                }

                if let extraLimit {
                    extraLimitLine(extraLimit)
                }
            } else {
                Text(title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(noDataText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func labelText(presentation: UsageLimitCellPresentation) -> String {
        guard showsWeeklyDots else { return title }
        return "\(title) · \(presentation.resetText)"
    }

    private func extraLimitLine(_ limit: RateLimit) -> some View {
        let presentation = UsageLimitCellFormatter.presentation(
            for: limit,
            language: language
        )
        return HStack(spacing: 4) {
            Text(L10n.tr("window.weekly_sonnet", language: language))
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text("\(presentation.percentText) / \(presentation.remainingText)")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

private struct WeekDotsView: View {
    let fillFractions: [Double]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(normalizedFractions.enumerated()), id: \.offset) { _, fraction in
                WeekDotSegment(fraction: fraction)
            }
        }
        .frame(height: 5)
    }

    private var normalizedFractions: [Double] {
        var fractions = Array(fillFractions.prefix(WeeklyWindowSegments.segmentCount))
        while fractions.count < WeeklyWindowSegments.segmentCount {
            fractions.append(0)
        }
        return fractions
    }
}

private struct WeekDotSegment: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.25))
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.blue.opacity(0.85))
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
    }
}

private enum ServiceBrand {
    case claude
    case codex

    var title: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    var subtitle: String {
        switch self {
        case .claude: return "Code"
        case .codex: return "OpenAI"
        }
    }

    var symbolName: String {
        switch self {
        case .claude: return "sparkles"
        case .codex: return "terminal.fill"
        }
    }
}

private extension View {
    func serviceCardBackground(tint: Color? = nil) -> some View {
        let baseColor = tint ?? Color.secondary
        return background(
            RoundedRectangle(cornerRadius: 8)
                .fill(baseColor.opacity(tint == nil ? 0.08 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint?.opacity(0.26) ?? Color.clear, lineWidth: 1)
        )
    }
}
