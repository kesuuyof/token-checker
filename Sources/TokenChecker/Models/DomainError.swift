import Foundation

enum DomainError: Error, Equatable, LocalizedError, Sendable {
    case keychainTokenMissing
    case anthropicUnauthorized
    case anthropicRateLimited(retryAfter: TimeInterval?)
    case anthropicHTTP(status: Int)
    case codexCLINotFound
    case codexProcessExited
    case codexRPCError(message: String)
    case decoding(String)
    case copilotTokenMissing
    case copilotUnauthorized
    case copilotNotSubscribed
    case copilotRateLimited(retryAfter: TimeInterval?)
    case copilotHTTP(status: Int)
    case timeout
    case network(String)

    var errorDescription: String? {
        switch self {
        case .keychainTokenMissing:
            return "Claude Code の OAuth トークンが Keychain に見つかりません。ターミナルで `claude login` を実行してください。"
        case .anthropicUnauthorized:
            return "Anthropic からの認証エラー (401)。`claude login` で再ログインしてください。"
        case .anthropicRateLimited(let retryAfter):
            if let sec = retryAfter {
                let mins = max(1, Int((sec / 60).rounded()))
                return "Anthropic API のレート制限に達しました。約 \(mins) 分後に自動で再試行します。"
            }
            return "Anthropic API のレート制限 (429)。次回ポーリングまで待機します。"
        case .anthropicHTTP(let status):
            return "Anthropic API エラー (status \(status))"
        case .codexCLINotFound:
            return "Codex CLI が見つかりません。`npm i -g @openai/codex` を実行してください。"
        case .codexProcessExited:
            return "codex app-server が終了しました。再起動を試みます。"
        case .codexRPCError(let message):
            return "Codex RPC エラー: \(message)"
        case .copilotTokenMissing:
            return "GitHub Copilot のトークンが見つかりません。Copilot CLI (`gh copilot`) や対応 IDE 拡張でログイン後に再試行してください。"
        case .copilotUnauthorized:
            return "GitHub Copilot の認証エラー。Copilot CLI または IDE 拡張で再ログインしてください。"
        case .copilotNotSubscribed:
            return "このアカウントには GitHub Copilot のサブスクリプションが見つかりません。"
        case .copilotRateLimited(let retryAfter):
            if let sec = retryAfter {
                let mins = max(1, Int((sec / 60).rounded()))
                return "GitHub Copilot API のレート制限に達しました。約 \(mins) 分後に自動で再試行します。"
            }
            return "GitHub Copilot API のレート制限 (429)。次回ポーリングまで待機します。"
        case .copilotHTTP(let status):
            return "GitHub Copilot API エラー (status \(status))"
        case .decoding(let detail):
            return "レスポンスのデコードに失敗: \(detail)"
        case .timeout:
            return "通信がタイムアウトしました。"
        case .network(let detail):
            return "ネットワークエラー: \(detail)"
        }
    }
}
