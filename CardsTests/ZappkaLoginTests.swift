import Foundation
import Testing
@testable import Cards

/// Replays canned responses in order and records what was sent. Never touches the network.
private final class StubTransport: @unchecked Sendable {
  private let lock = NSLock()
  private var responses: [(Int, String)]
  private(set) var requests: [URLRequest] = []

  init(_ responses: [(Int, String)]) { self.responses = responses }

  var client: ZappkaLoginClient {
    ZappkaLoginClient { request in try self.handle(request) }
  }

  private func handle(_ request: URLRequest) throws -> (Data, URLResponse) {
    lock.lock()
    defer { lock.unlock() }
    requests.append(request)
    guard !responses.isEmpty else { throw URLError(.notConnectedToInternet) }
    let (status, body) = responses.removeFirst()
    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (Data(body.utf8), response)
  }
}

private func json(_ request: URLRequest) -> [String: Any] {
  (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
}

// Made-up tokens and secret.
private let anonymousToken = "anon-token-123"
private let signedInToken = "signed-token-456"
private let fakeSecret = "00112233445566778899aabbccddeeff00112233"

private let happyResponses: [(Int, String)] = [
  (200, #"{"idToken":"\#(anonymousToken)","refreshToken":"r"}"#),
  (200, #"{"users":[]}"#),
  (200, #"{"data":{"sendVerificationCode":{"__typename":"SendVerificationCodeResult","retryAfterSeconds":45}}}"#),
  (200, #"{"data":{"signIn":{"__typename":"SignInResult","customToken":"custom-789"}}}"#),
  (200, #"{"idToken":"\#(signedInToken)"}"#),
  (200, #"{"data":{"qrCode":{"__typename":"QRCode","loyalSecret":"\#(fakeSecret)","paySecret":"ff","ployId":"TestUser_1"}}}"#),
]

struct ZappkaLoginTests {
  @Test func happyPathSendsTheOfficialSequence() async throws {
    let stub = StubTransport(happyResponses)
    let pending = try await stub.client.requestCode(phone: "600 700 800")
    #expect(pending.idToken == anonymousToken)
    #expect(pending.phone == "600700800")
    #expect(pending.retryAfterSeconds == 45)

    let credentials = try await stub.client.finish(pending, code: "123456")
    #expect(credentials == ZappkaCredentials(userId: "TestUser_1", secretHex: fakeSecret))
    #expect(credentials.isValid)

    let r = stub.requests
    try #require(r.count == 6)
    #expect(r[0].url?.path().hasSuffix("/signupNewUser") == true)
    #expect(r[0].url?.query()?.contains("key=\(ZappkaAPI.firebaseAPIKey)") == true)
    #expect(r[0].value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") == "pl.zabka.apb2c")
    #expect(r[1].url?.path().hasSuffix("/getAccountInfo") == true)
    #expect(json(r[1])["idToken"] as? String == anonymousToken)

    #expect(r[2].url == ZappkaAPI.superAccount)
    #expect(json(r[2])["operationName"] as? String == "SendCode")
    let phone = ((json(r[2])["variables"] as? [String: Any])?["input"] as? [String: Any])?["phoneNumber"] as? [String: String]
    #expect(phone == ["countryCode": "48", "nationalNumber": "600700800"])
    #expect(r[2].value(forHTTPHeaderField: "Authorization") == anonymousToken)
    #expect(r[2].value(forHTTPHeaderField: "X-Client-Key") == ZappkaAPI.clientKey)

    #expect(json(r[3])["operationName"] as? String == "SignIn")
    let input = (json(r[3])["variables"] as? [String: Any])?["input"] as? [String: Any]
    #expect(input?["verificationCode"] as? String == "123456")
    #expect(r[3].value(forHTTPHeaderField: "Authorization") == anonymousToken)

    #expect(r[4].url?.path().hasSuffix("/verifyCustomToken") == true)
    #expect(json(r[4])["token"] as? String == "custom-789")

    #expect(r[5].url == ZappkaAPI.api)
    #expect(json(r[5])["operationName"] as? String == "QRCode")
    #expect(r[5].value(forHTTPHeaderField: "Authorization") == signedInToken)
  }

  @Test func graphQLErrorOnSignInIsWrongCode() async throws {
    let stub = StubTransport(Array(happyResponses.prefix(3)) + [
      (200, #"{"data":null,"errors":[{"message":"Invalid verification code"}]}"#),
    ])
    let pending = try await stub.client.requestCode(phone: "600700800")
    await #expect(throws: ZappkaLoginError.wrongCode) {
      try await stub.client.finish(pending, code: "000000")
    }
  }

  @Test func rateLimitIsTooManyAttempts() async throws {
    let stub = StubTransport(Array(happyResponses.prefix(2)) + [
      (200, #"{"errors":[{"message":"Too many requests","extensions":{"code":"RATE_LIMITED"}}]}"#),
    ])
    await #expect(throws: ZappkaLoginError.tooManyAttempts) {
      try await stub.client.requestCode(phone: "600700800")
    }
  }

  @Test func httpFailureGivesNoCredentials() async throws {
    let stub = StubTransport([(400, #"{"error":{"message":"API_KEY_INVALID"}}"#)])
    await #expect(throws: ZappkaLoginError.unexpectedResponse) {
      try await stub.client.requestCode(phone: "600700800")
    }
  }

  @Test func offlineIsNetworkError() async throws {
    let stub = StubTransport([])
    await #expect(throws: ZappkaLoginError.network) {
      try await stub.client.requestCode(phone: "600700800")
    }
  }

  @Test func invalidPhoneSendsNothing() async throws {
    let stub = StubTransport(happyResponses)
    await #expect(throws: ZappkaLoginError.invalidPhone) {
      try await stub.client.requestCode(phone: "12345")
    }
    #expect(stub.requests.isEmpty)
  }

  @Test(arguments: ["600 700 800", "+48600700800", "0048 600-700-800", "600-700-800", "\u{202A}+48 600 700 800\u{202C}"])
  func phoneNormalizes(_ raw: String) {
    #expect(ZappkaLoginClient.normalizePhone(raw) == "600700800")
  }

  @Test(arguments: [
    ("+48 600 700 800", "600 700 800"),
    ("0048600700800", "600700800"),
    ("\u{202A}+48 600 700 800\u{202C}", "600 700 800\u{202C}"),
    ("+48", ""),
    ("600 700 800", "600 700 800"),
    ("+49 600 700 800", "+49 600 700 800"),
  ])
  func phoneStripsCountryPrefix(_ raw: String, _ expected: String) {
    #expect(ZappkaLoginClient.stripCountryPrefix(raw) == expected)
  }

  @Test func phoneFormatsInThrees() {
    #expect(ZappkaLoginClient.formatPhone("505968488") == "505 968 488")
  }

  @Test(arguments: ["", "60070080", "6007008001", "60070080a", "+49600700800"])
  func phoneRejects(_ raw: String) {
    #expect(ZappkaLoginClient.normalizePhone(raw) == nil)
  }

  @MainActor @Test func draftApplyFillsCredentialsAndKeepsNumber() {
    let draft = EditorDraft(preset: Presets.zappka)
    draft.rawData = "123"
    draft.apply(ZappkaCredentials(userId: " TestUser_1 ", secretHex: "AABB CCDD"))
    #expect(draft.zappkaUserId == "TestUser_1")
    #expect(draft.zappkaSecret == "aabbccdd")
    #expect(draft.rawData == "123")

    draft.signOutOfZappka()
    #expect(draft.zappkaUserId.isEmpty && draft.zappkaSecret.isEmpty)
    #expect(!draft.canSave, "a Żappka card needs credentials")
  }
}
