import SwiftUI
import AppKit

struct UsagePopoverView: View {
    @Bindable var viewModel: UsageViewModel
    @Bindable var languageStore: LanguageStore
    @ObservedObject var launchAtLogin: LaunchAtLoginStore

    private var language: AppLanguage { languageStore.selectedLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            usageMatrix
            settingsBlock
            footer
        }
        .padding(14)
        .frame(width: 500)
    }

    private var header: some View {
        HStack {
            Text("Token Checker")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text(L10n.tr("usage.matrix.overview", language: language))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var usageMatrix: some View {
        VStack(alignment: .leading, spacing: 7) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 7) {
                GridRow {
                    matrixHeader(L10n.tr("usage.matrix.agent", language: language))
                    matrixHeader(L10n.tr("window.five_hour", language: language))
                    matrixHeader(L10n.tr("window.weekly", language: language))
                    matrixHeader(L10n.tr("usage.matrix.calendar", language: language))
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                UsageMatrixRow(
                    title: "Claude",
                    subtitle: "Code",
                    brand: .claude,
                    result: viewModel.snapshot.claude,
                    language: language,
                    loginAction: { viewModel.openClaudeLogin() }
                )

                UsageMatrixRow(
                    title: "Codex",
                    subtitle: "OpenAI",
                    brand: .codex,
                    result: viewModel.snapshot.codex,
                    language: language,
                    loginAction: { viewModel.openCodexLogin() }
                )

                UsageMatrixRow(
                    title: "Copilot",
                    subtitle: "GitHub",
                    brand: .copilot,
                    result: viewModel.snapshot.copilot,
                    language: language,
                    loginAction: { viewModel.openCopilotLogin() }
                )
            }
        }
    }

    private func matrixHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
    }

    private var settingsBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider()

            HStack {
                Text(L10n.tr("settings.refresh_interval", language: language))
                    .settingsLabelStyle()
                Spacer()
                Picker("", selection: $viewModel.pollingInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.label(language: language)).tag(interval)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            HStack {
                Text(L10n.tr("settings.language", language: language))
                    .settingsLabelStyle()
                Spacer()
                Picker("", selection: $languageStore.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(L10n.tr(option.displayKey, language: option)).tag(option)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            HStack {
                Text(L10n.tr("settings.launch_at_login", language: language))
                    .settingsLabelStyle()
                Spacer()
                Toggle("", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { _ in launchAtLogin.toggle() }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
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

                Button(L10n.tr("footer.quit", language: language)) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct UsageMatrixRow: View {
    let title: String
    let subtitle: String
    let brand: ServiceBrand
    let result: Result<ServiceUsage, DomainError>?
    let language: AppLanguage
    let loginAction: () -> Void

    var body: some View {
        switch result {
        case .none:
            loadingRow
        case .some(.success(let usage)):
            successRow(usage)
        case .some(.failure(let error)):
            errorRow(error)
        }
    }

    private var loadingRow: some View {
        GridRow {
            agentCell
            Text(L10n.tr("status.loading", language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .gridCellColumns(3)
        }
        .matrixRowBackground()
    }

    private func successRow(_ usage: ServiceUsage) -> some View {
        GridRow {
            agentCell
            LimitCellView(limit: usage.fiveHour, language: language)
                .frame(minWidth: 145)
            LimitCellView(limit: usage.weekly, language: language, extraLimit: usage.weeklySonnet)
                .frame(minWidth: 145)
            calendarButton(for: usage.weekly)
        }
        .matrixRowBackground()
    }

    private func errorRow(_ error: DomainError) -> some View {
        GridRow {
            agentCell
            HStack(spacing: 6) {
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
                Spacer()
            }
            .gridCellColumns(2)
            Button {
                loginAction()
            } label: {
                Image(systemName: "person.badge.key")
            }
            .buttonStyle(.borderless)
            .help(L10n.format("service.login.help", language: language, title))
        }
        .matrixRowBackground(tint: .orange)
    }

    private var agentCell: some View {
        HStack(spacing: 7) {
            brandMark
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 15)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 76, alignment: .leading)
        .frame(minHeight: 46)
    }

    @ViewBuilder
    private var brandMark: some View {
        switch brand {
        case .claude:
            Image(systemName: "sparkles")
        case .codex:
            Image(systemName: "terminal.fill")
        case .copilot:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
        }
    }

    @ViewBuilder
    private func calendarButton(for weekly: RateLimit?) -> some View {
        if let weekly,
           let calendarURL = weeklyReminderURL(for: weekly)
        {
            Button {
                NSWorkspace.shared.open(calendarURL)
            } label: {
                Image(systemName: "calendar.badge.plus")
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("calendar.reset_reminder.help", language: language))
            .frame(width: 34)
            .frame(minHeight: 46)
        } else {
            Image(systemName: "minus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 34)
                .frame(minHeight: 46)
        }
    }

    private func weeklyReminderURL(for limit: RateLimit) -> URL? {
        switch brand {
        case .claude, .codex:
            return GoogleCalendarEventBuilder.eventURL(
                serviceName: title,
                resetDate: limit.resetsAt,
                language: language
            )
        case .copilot:
            return nil
        }
    }
}

private struct LimitCellView: View {
    let limit: RateLimit?
    let language: AppLanguage
    var extraLimit: RateLimit?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let limit {
                let presentation = UsageLimitCellFormatter.presentation(
                    for: limit,
                    language: language
                )
                HStack(alignment: .firstTextBaseline) {
                    Text(presentation.percentText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color(for: limit.utilization))
                    Spacer(minLength: 6)
                    Text(presentation.remainingText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color(for: limit.utilization))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.tr("usage.matrix.reset", language: language))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 6)
                    Text(presentation.resetText)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                ProgressBarView(value: limit.utilization, height: 6)
                if let extraLimit {
                    extraLimitLine(extraLimit)
                }
            } else {
                Text(L10n.tr("usage.matrix.no_data", language: language))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 46)
    }

    private func extraLimitLine(_ limit: RateLimit) -> some View {
        let presentation = UsageLimitCellFormatter.presentation(
            for: limit,
            language: language
        )
        return HStack(spacing: 5) {
            Text(L10n.tr("window.weekly_sonnet", language: language))
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(presentation.percentText)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color(for: limit.utilization))
            Text(presentation.remainingText)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func color(for value: Double) -> Color {
        if value < 0.7 { return .green }
        if value < 0.85 { return .orange }
        return .red
    }
}

private extension View {
    func settingsLabelStyle() -> some View {
        font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    func matrixRowBackground(tint: Color? = nil) -> some View {
        let baseColor = tint ?? Color.secondary
        return padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(baseColor.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tint?.opacity(0.24) ?? Color.clear, lineWidth: 1)
            )
    }
}
