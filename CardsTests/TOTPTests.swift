import Foundation
import Testing
@testable import Cards

struct TOTPTests {
  // RFC 6238 appendix B, SHA1, ASCII secret "12345678901234567890".
  static let rfcSecret = Data("12345678901234567890".utf8)

  @Test(arguments: [(59.0, "287082"), (1_111_111_109, "081804"), (1_234_567_890, "005924")])
  func rfcVectors(time: TimeInterval, expected: String) {
    #expect(TOTP(secret: Self.rfcSecret).code(at: Date(timeIntervalSince1970: time)) == expected)
  }

  @Test func eightDigits() {
    #expect(TOTP(secret: Self.rfcSecret, digits: 8).code(at: Date(timeIntervalSince1970: 59)) == "94287082")
  }

  @Test func windowBoundaries() {
    let totp = TOTP(secret: Self.rfcSecret)
    #expect(totp.window(containing: Date(timeIntervalSince1970: 30)) == DateInterval(start: Date(timeIntervalSince1970: 30), duration: 30))
    #expect(totp.window(containing: Date(timeIntervalSince1970: 59.9)) == DateInterval(start: Date(timeIntervalSince1970: 30), duration: 30))
  }
}

struct ZappkaTests {
  // Made-up secret, not a real credential.
  static let fakeSecret = "0f1e2d3c4b5a69788796a5b4c3d2e1f00a1b2c3d"

  @Test func normalizeSecret() {
    #expect(ZappkaCredentials.normalizeSecret(" AB cd\n12 ") == "abcd12")
  }

  @Test func messySecretGivesSameCode() {
    let messy = ZappkaCredentials(userId: "u1", secretHex: " 0F1E 2D3C\n4B5A69788796A5B4C3D2E1F00A1B2C3D ")
    let clean = ZappkaCredentials(userId: "u1", secretHex: Self.fakeSecret)
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(messy.secretHex == clean.secretHex)
    #expect(Zappka.code(for: messy, at: date) == Zappka.code(for: clean, at: date))
  }

  @Test func matchesRFCWhenFedTheRFCSecret() {
    let creds = ZappkaCredentials(userId: "u1", secretHex: "3132333435363738393031323334353637383930")
    #expect(Zappka.code(for: creds, at: Date(timeIntervalSince1970: 59)) == "287082")
  }

  @Test func payloadFormat() {
    #expect(Zappka.payload(userId: "123456", code: "000042") == "https://srln.pl/view/dashboard?ploy=123456&loyal=000042")
    let creds = ZappkaCredentials(userId: "123456", secretHex: "3132333435363738393031323334353637383930")
    #expect(Zappka.payload(for: creds, at: Date(timeIntervalSince1970: 59)) == "https://srln.pl/view/dashboard?ploy=123456&loyal=287082")
  }

  @Test func invalidSecretsAreIssuesNotCrashes() {
    #expect(ZappkaCredentials(userId: "u", secretHex: "xyz1").validate().contains(.secretNotHex))
    #expect(ZappkaCredentials(userId: "u", secretHex: "abc").validate().contains(.secretOddLength))
    #expect(ZappkaCredentials(userId: "", secretHex: "").validate() == [.missingUserId, .missingSecret])
    #expect(ZappkaCredentials(userId: "u", secretHex: "abcd").validate() == [.secretShort])
    #expect(ZappkaCredentials(userId: "u", secretHex: "xyz1").secretData == nil)
    #expect(Zappka.payload(for: ZappkaCredentials(userId: "u", secretHex: "abc"), at: .now) == nil)
  }
}
