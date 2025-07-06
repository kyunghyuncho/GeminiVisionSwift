import Foundation
import Security

class KeychainHelper {
    
    static let shared = KeychainHelper()
    // A unique string to identify your app's keychain entries
    private let service = "me.kyunghyuncho.GeminiVisionSwift"

    private init() {}
    
    func save(apiKey: String, for account: String) -> Bool {
        guard let data = apiKey.data(using: .utf8) else { return false }
        
        // This query identifies the keychain item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        
        // Attributes to update or add, in this case, the secret data
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        // First, try to update an existing item
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // If the item doesn't exist, add it
        if status == errSecItemNotFound {
            let addQuery = query.merging(attributes) { (_, new) in new }
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        
        return status == errSecSuccess
    }
    
    func load(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
}
