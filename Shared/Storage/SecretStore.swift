import Foundation
import Security

/// Keychain storage for Żappka secrets, shared with the widget via a keychain access group.
/// Never log secret values.
struct SecretStore: Sendable {
  enum Error: Swift.Error, Equatable { case keychain(OSStatus) }

  /// `<TeamPrefix>io.legiec.cards.shared`, injected into Info.plist at build time.
  static let accessGroup: String? = Bundle.main.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String

  var service = "io.legiec.cards.zappka"
  var accessGroup: String? = SecretStore.accessGroup

  func zappkaSecret(for cardID: UUID) throws -> String? {
    var query = baseQuery(cardID)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess: return (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
    case errSecItemNotFound: return nil
    default: throw Error.keychain(status)
    }
  }

  /// `nil` deletes.
  func setZappkaSecret(_ hex: String?, for cardID: UUID) throws {
    guard let hex, !hex.isEmpty else {
      let status = SecItemDelete(baseQuery(cardID) as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else { throw Error.keychain(status) }
      return
    }
    let data = Data(hex.utf8)
    let update: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]
    let status = SecItemUpdate(baseQuery(cardID) as CFDictionary, update as CFDictionary)
    if status == errSecItemNotFound {
      var add = baseQuery(cardID)
      add.merge(update) { $1 }
      let addStatus = SecItemAdd(add as CFDictionary, nil)
      guard addStatus == errSecSuccess else { throw Error.keychain(addStatus) }
    } else if status != errSecSuccess {
      throw Error.keychain(status)
    }
  }

  private func baseQuery(_ cardID: UUID) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: cardID.uuidString,
      kSecAttrSynchronizable as String: false,
    ]
    // The simulator can run unsigned builds whose entitlements don't carry the group;
    // an unexpanded or missing group falls back to the app's default group.
    if let accessGroup, !accessGroup.hasPrefix("$(") {
      query[kSecAttrAccessGroup as String] = accessGroup
    }
    return query
  }
}
