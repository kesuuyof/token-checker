@testable import TokenChecker
import XCTest

final class CodexOAuthCredentialsStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexOAuthCredentialsStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testLoadReadsExistingOAuthTokensFromAuthFile() throws {
        let authURL = temporaryDirectory.appendingPathComponent("auth.json")
        try Data(
            #"{"tokens":{"access_token":"access","refresh_token":"refresh","account_id":"acct"},"last_refresh":"2026-07-09T00:00:00Z"}"#.utf8
        ).write(to: authURL)

        let credentials = try CodexOAuthCredentialsStore(homeURL: temporaryDirectory).load()

        XCTAssertEqual(credentials.accessToken, "access")
        XCTAssertEqual(credentials.refreshToken, "refresh")
        XCTAssertEqual(credentials.accountId, "acct")
    }

    func testSavePreservesUnknownFieldsAndUsesPrivatePermissions() throws {
        let authURL = temporaryDirectory.appendingPathComponent("auth.json")
        try Data(
            #"{"custom":"keep","tokens":{"access_token":"old","refresh_token":"old"}}"#.utf8
        ).write(to: authURL)

        try CodexOAuthCredentialsStore(homeURL: temporaryDirectory).save(
            CodexOAuthCredentials(
                accessToken: "new-access",
                refreshToken: "new-refresh",
                accountId: "acct",
                lastRefresh: Date(timeIntervalSince1970: 1_800_000_000)
            )
        )

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: authURL)) as? [String: Any]
        XCTAssertEqual(json?["custom"] as? String, "keep")
        let tokens = json?["tokens"] as? [String: String]
        XCTAssertEqual(tokens?["access_token"], "new-access")
        XCTAssertEqual(tokens?["account_id"], "acct")
        XCTAssertEqual(try filePermissions(at: authURL), 0o600)
    }

    func testRefreshReturnsRotatedTokens() async throws {
        let refresher = CodexTokenRefresher { request in
            XCTAssertEqual(request.url?.absoluteString, "https://auth.openai.com/oauth/token")
            XCTAssertEqual(request.httpMethod, "POST")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (
                Data(#"{"access_token":"new-access","refresh_token":"new-refresh","account_id":"new-account"}"#.utf8),
                response
            )
        }

        let refreshed = try await refresher.refresh(
            CodexOAuthCredentials(accessToken: "old", refreshToken: "old-refresh", accountId: "old-account", lastRefresh: nil)
        )

        XCTAssertEqual(refreshed.accessToken, "new-access")
        XCTAssertEqual(refreshed.refreshToken, "new-refresh")
        XCTAssertEqual(refreshed.accountId, "new-account")
    }

    private func filePermissions(at url: URL) throws -> UInt16 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return UInt16(truncating: attributes[.posixPermissions] as? NSNumber ?? 0)
    }
}
