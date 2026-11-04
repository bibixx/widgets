import Foundation

/// What the official Żabka iOS app sends when it signs in. Copied from iGerman00's
/// `login-for-secrets.py` (github.com/iGerman00/zabka-totp-webapp); when sign-in stops
/// working, compare against that script first.
enum ZappkaAPI {
  static let firebaseAPIKey = "AIzaSyByV8PCH4umClqDWZRMy2nSm7DXjQOWt1U"
  static let identityToolkit = URL(string: "https://www.googleapis.com/identitytoolkit/v3/relyingparty/")!
  static let superAccount = URL(string: "https://super-account.spapp.zabka.pl/")!
  static let api = URL(string: "https://api.spapp.zabka.pl/")!

  static let clientType = "CLIENT_TYPE_IOS"
  static let bundleIdentifier = "pl.zabka.apb2c"
  static let firebaseClientVersion = "iOS/FirebaseSDK/10.26.0/FirebaseCore-iOS"
  static let firebaseUserAgent = "FirebaseAuth.iOS/10.26.0 \(bundleIdentifier)/4.2.0 iPhone/18.2 hw/iPhone16_1"
  static let gmpID = "1:123456789012:ios:e7e7e7e7e7e7e7e7e7e7e7"

  static let appUserAgent = "SuperApp/99999 CFNetwork/3860.500.112 Darwin/25.4.0"
  static let clientKey = "l6u0R9biQcbEvZy5UybJxw"
  static let apolloClientName = "pl.zabka.apb2c-apollo-ios"
  static let apolloClientVersion = "5.35.1+99999"
  static let apolloAccept = "multipart/mixed;deferSpec=20220824,application/graphql-response+json,application/json"

  static let countryCode = "48"

  static let sendCodeQuery = "mutation SendCode($input: SendVerificationCodeInput!) { sendVerificationCode(input: $input) { __typename retryAfterSeconds } }"
  static let signInQuery = "mutation SignIn($input: SignInInput!) { signIn(input: $input) { __typename customToken } }"
  static let qrCodeQuery = "query QRCode { qrCode { __typename loyalSecret paySecret ployId } }"
}

enum ZappkaLoginError: LocalizedError, Equatable {
  case invalidPhone, wrongCode, tooManyAttempts, network, unexpectedResponse

  var errorDescription: String? {
    switch self {
    case .invalidPhone: "Enter a 9-digit Polish phone number."
    case .wrongCode: "That code didn't work. Check the SMS and try again."
    case .tooManyAttempts: "Too many attempts. Wait a moment and try again."
    case .network: "Couldn't reach Żabka. Check your connection."
    case .unexpectedResponse: "Żabka sent back something unexpected. Sign-in may have changed."
    }
  }
}

/// Signs in to Żabka with a phone number and SMS code and fetches the Żappka code secret.
/// Nothing here is persisted: tokens live only in `PendingSignIn` until the sheet closes.
/// Never log requests or responses; they carry tokens and the secret.
struct ZappkaLoginClient: Sendable {
  typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  struct PendingSignIn: Sendable, Equatable {
    /// The anonymous Firebase user's token; SMS sign-in upgrades this user.
    let idToken: String
    let phone: String
    let retryAfterSeconds: Int?
  }

  private let send: Transport

  init(send: @escaping Transport) { self.send = send }

  init() {
    let session = URLSession(configuration: .ephemeral)
    self.init(send: { try await session.data(for: $0) })
  }

  /// 9 digits, with an optional +48 / 0048 prefix and spaces or dashes; nil otherwise.
  static func normalizePhone(_ raw: String) -> String? {
    var digits = raw.filter { !" -\u{00A0}".contains($0) }
    for prefix in ["+48", "0048"] where digits.hasPrefix(prefix) && digits.count > 9 {
      digits.removeFirst(prefix.count)
    }
    guard digits.count == 9, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else { return nil }
    return digits
  }

  // MARK: Flow

  /// Creates an anonymous user and texts a code to `phone`.
  func requestCode(phone raw: String) async throws -> PendingSignIn {
    guard let phone = Self.normalizePhone(raw) else { throw ZappkaLoginError.invalidPhone }
    let signup: FirebaseToken = try await firebase("signupNewUser", body: [
      "returnSecureToken": true, "clientType": ZappkaAPI.clientType,
    ])
    let _: Ignored = try await firebase("getAccountInfo", body: ["idToken": signup.idToken])
    return try await sendCode(token: signup.idToken, phone: phone)
  }

  func resendCode(_ pending: PendingSignIn) async throws -> PendingSignIn {
    try await sendCode(token: pending.idToken, phone: pending.phone)
  }

  /// Signs in with the SMS code and returns the card's User ID and secret.
  func finish(_ pending: PendingSignIn, code raw: String) async throws -> ZappkaCredentials {
    let code = raw.filter(\.isNumber)
    guard !code.isEmpty else { throw ZappkaLoginError.wrongCode }
    let signIn: SignInData = try await graphQL(
      ZappkaAPI.superAccount, operation: "SignIn", type: "mutation", query: ZappkaAPI.signInQuery,
      variables: ["input": ["phoneNumber": phoneVariable(pending.phone), "verificationCode": code]],
      token: pending.idToken, superAccount: true, failure: .wrongCode)
    guard let customToken = signIn.signIn?.customToken, !customToken.isEmpty else { throw ZappkaLoginError.wrongCode }

    let verified: FirebaseToken = try await firebase("verifyCustomToken", body: [
      "token": customToken, "returnSecureToken": true,
    ])

    let qr: QRCodeData = try await graphQL(
      ZappkaAPI.api, operation: "QRCode", type: "query", query: ZappkaAPI.qrCodeQuery,
      variables: [:], token: verified.idToken, superAccount: false, failure: .unexpectedResponse)
    guard let ployId = qr.qrCode?.ployId, let secret = qr.qrCode?.loyalSecret else {
      throw ZappkaLoginError.unexpectedResponse
    }
    let credentials = ZappkaCredentials(userId: ployId, secretHex: secret)
    guard credentials.isValid else { throw ZappkaLoginError.unexpectedResponse }
    return credentials
  }

  private func sendCode(token: String, phone: String) async throws -> PendingSignIn {
    let data: SendCodeData = try await graphQL(
      ZappkaAPI.superAccount, operation: "SendCode", type: "mutation", query: ZappkaAPI.sendCodeQuery,
      variables: ["input": ["phoneNumber": phoneVariable(phone)]],
      token: token, superAccount: true, failure: .unexpectedResponse)
    return PendingSignIn(idToken: token, phone: phone, retryAfterSeconds: data.sendVerificationCode?.retryAfterSeconds)
  }

  private func phoneVariable(_ phone: String) -> [String: String] {
    ["countryCode": ZappkaAPI.countryCode, "nationalNumber": phone]
  }

  // MARK: Requests

  private func firebase<Response: Decodable>(_ method: String, body: [String: Any]) async throws -> Response {
    var components = URLComponents(url: ZappkaAPI.identityToolkit.appending(path: method), resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "key", value: ZappkaAPI.firebaseAPIKey)]
    var request = URLRequest(url: components.url!)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(ZappkaAPI.firebaseUserAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("\(ZappkaAPI.firebaseClientVersion)/FirebaseCore-iOS", forHTTPHeaderField: "X-Client-Version")
    request.setValue(ZappkaAPI.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    request.setValue(ZappkaAPI.gmpID, forHTTPHeaderField: "X-Firebase-GMPID")

    let (data, status) = try await perform(request)
    guard (200..<300).contains(status) else {
      let message = (try? JSONDecoder().decode(FirebaseError.self, from: data))?.error.message ?? ""
      throw message.contains("TOO_MANY") ? ZappkaLoginError.tooManyAttempts : ZappkaLoginError.unexpectedResponse
    }
    guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else { throw ZappkaLoginError.unexpectedResponse }
    return decoded
  }

  private func graphQL<Payload: Decodable>(
    _ url: URL, operation: String, type: String, query: String, variables: [String: Any],
    token: String, superAccount: Bool, failure: ZappkaLoginError
  ) async throws -> Payload {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "operationName": operation, "query": query, "variables": variables,
    ])
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(token, forHTTPHeaderField: "Authorization")
    request.setValue(ZappkaAPI.appUserAgent, forHTTPHeaderField: "User-Agent")
    request.setValue(ZappkaAPI.apolloClientName, forHTTPHeaderField: "apollographql-client-name")
    request.setValue(ZappkaAPI.apolloClientVersion, forHTTPHeaderField: "apollographql-client-version")
    request.setValue(operation, forHTTPHeaderField: "X-APOLLO-OPERATION-NAME")
    request.setValue(type, forHTTPHeaderField: "X-APOLLO-OPERATION-TYPE")
    request.setValue("<null>", forHTTPHeaderField: "If-None-Match")
    if superAccount {
      request.setValue(ZappkaAPI.clientKey, forHTTPHeaderField: "X-Client-Key")
      request.setValue(ZappkaAPI.apolloAccept, forHTTPHeaderField: "Accept")
    }

    let (data, status) = try await perform(request)
    let response = try? JSONDecoder().decode(GraphQLResponse<Payload>.self, from: data)
    if let errors = response?.errors, !errors.isEmpty {
      let text = errors.map { "\($0.message ?? "") \($0.extensions?.code ?? "")" }.joined(separator: " ").lowercased()
      if ["too many", "too_many", "limit", "retry"].contains(where: text.contains) { throw ZappkaLoginError.tooManyAttempts }
      throw failure
    }
    guard (200..<300).contains(status), let payload = response?.data else { throw ZappkaLoginError.unexpectedResponse }
    return payload
  }

  private func perform(_ request: URLRequest) async throws -> (Data, Int) {
    do {
      let (data, response) = try await send(request)
      return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    } catch is URLError {
      throw ZappkaLoginError.network
    }
  }

  // MARK: Responses

  private struct FirebaseToken: Decodable { let idToken: String }
  private struct FirebaseError: Decodable {
    struct Body: Decodable { let message: String? }
    let error: Body
  }
  private struct Ignored: Decodable {}

  private struct GraphQLResponse<Payload: Decodable>: Decodable {
    struct Error: Decodable {
      struct Extensions: Decodable { let code: String? }
      let message: String?
      let extensions: Extensions?
    }
    let data: Payload?
    let errors: [Error]?
  }

  private struct SendCodeData: Decodable {
    struct Result: Decodable { let retryAfterSeconds: Int? }
    let sendVerificationCode: Result?
  }
  private struct SignInData: Decodable {
    struct Result: Decodable { let customToken: String? }
    let signIn: Result?
  }
  private struct QRCodeData: Decodable {
    struct Result: Decodable { let loyalSecret: String?; let ployId: String? }
    let qrCode: Result?
  }
}
