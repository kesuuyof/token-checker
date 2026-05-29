import Foundation

/// GitHub Copilot 関連の OAuth トークンを取得する。
///
/// 取得経路は次の優先度:
///  1. Copilot.vim / 公式 Language Server がデバイスフロー後に書き出す
///     `~/.config/github-copilot/apps.json`（旧名 `hosts.json`）
///  2. `gh auth token`（gh CLI が Keychain に保存している OAuth トークン）
///
/// `gh copilot` 拡張だけインストールしても (1) のファイルは作られないため、
/// その場合は (2) を使う。`copilot_internal/user` エンドポイントは `gho_` トークンでも
/// 200 を返すことを確認済み。
struct GitHubCopilotTokenSource: Sendable {
    func readAccessToken() async throws -> String {
        // (1) Copilot 公式パス
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".config/github-copilot/apps.json"),
            home.appendingPathComponent(".config/github-copilot/hosts.json"),
        ]
        for url in candidates {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let token = Self.extractToken(from: data) {
                return token
            }
        }

        // (2) gh CLI フォールバック
        if let token = try await Self.readGhToken(), !token.isEmpty {
            return token
        }

        throw DomainError.copilotTokenMissing
    }

    /// `gh auth token` を spawn して標準出力を読む。`gh` が無い／未ログインなら nil。
    private static func readGhToken() async throws -> String? {
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let ghPath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["auth", "token"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { _ in cont.resume() }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    cont.resume(throwing: error)
                }
            }
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let token = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return token
    }

    /// `{ "<key>": { "oauth_token": "..." } }` のうち github.com を含むキーを優先して返す。
    private static func extractToken(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let preferred = json.first { (key, _) in key.contains("github.com") }
        let entry = preferred?.value ?? json.values.first
        guard let dict = entry as? [String: Any],
              let token = dict["oauth_token"] as? String,
              !token.isEmpty
        else { return nil }
        return token
    }
}
