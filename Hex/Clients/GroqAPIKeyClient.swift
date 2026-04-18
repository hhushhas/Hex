import Dependencies
import DependenciesMacros
import Foundation
import HexCore
import Security

private let groqLogger = HexLog.groq

enum GroqAPIKeyStoreError: LocalizedError {
  case emptyKey
  case unexpectedStatus(OSStatus)

  var errorDescription: String? {
    switch self {
    case .emptyKey:
      return "Enter a Groq API key before saving."
    case let .unexpectedStatus(status):
      if let message = SecCopyErrorMessageString(status, nil) as String? {
        return message
      }
      return "Keychain error (\(status))."
    }
  }
}

enum GroqAPIKeyStore {
  private static let service = HexLog.subsystem
  private static let account = "groq-api-key"

  static func hasAPIKey() -> Bool {
    (try? load())?.isEmpty == false
  }

  static func load() throws -> String? {
    var query = baseQuery()
    query[kSecReturnData as String] = kCFBooleanTrue
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    switch status {
    case errSecSuccess:
      guard
        let data = item as? Data,
        let key = String(data: data, encoding: .utf8),
        !key.isEmpty
      else {
        return nil
      }
      return key
    case errSecItemNotFound:
      return nil
    default:
      groqLogger.error("Groq API key load failed status=\(status)")
      throw GroqAPIKeyStoreError.unexpectedStatus(status)
    }
  }

  static func save(_ apiKey: String) throws {
    let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw GroqAPIKeyStoreError.emptyKey
    }

    let data = Data(trimmed.utf8)
    let status = SecItemCopyMatching(baseQuery() as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      let attributes = [kSecValueData as String: data] as CFDictionary
      let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes)
      guard updateStatus == errSecSuccess else {
        groqLogger.error("Groq API key update failed status=\(updateStatus)")
        throw GroqAPIKeyStoreError.unexpectedStatus(updateStatus)
      }
    case errSecItemNotFound:
      var query = baseQuery()
      query[kSecValueData as String] = data
      let addStatus = SecItemAdd(query as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        groqLogger.error("Groq API key save failed status=\(addStatus)")
        throw GroqAPIKeyStoreError.unexpectedStatus(addStatus)
      }
    default:
      groqLogger.error("Groq API key lookup before save failed status=\(status)")
      throw GroqAPIKeyStoreError.unexpectedStatus(status)
    }
  }

  static func delete() throws {
    let status = SecItemDelete(baseQuery() as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      groqLogger.error("Groq API key delete failed status=\(status)")
      throw GroqAPIKeyStoreError.unexpectedStatus(status)
    }
  }

  private static func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

@DependencyClient
struct GroqAPIKeyClient {
  var hasAPIKey: @Sendable () async -> Bool = { false }
  var saveAPIKey: @Sendable (String) async throws -> Void
  var deleteAPIKey: @Sendable () async throws -> Void
}

extension GroqAPIKeyClient: DependencyKey {
  static let liveValue = Self(
    hasAPIKey: {
      GroqAPIKeyStore.hasAPIKey()
    },
    saveAPIKey: { apiKey in
      try GroqAPIKeyStore.save(apiKey)
    },
    deleteAPIKey: {
      try GroqAPIKeyStore.delete()
    }
  )
}

extension DependencyValues {
  var groqAPIKey: GroqAPIKeyClient {
    get { self[GroqAPIKeyClient.self] }
    set { self[GroqAPIKeyClient.self] = newValue }
  }
}
