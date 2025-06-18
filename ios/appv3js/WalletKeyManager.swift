import Foundation
import CryptoKit
import Security
import LocalAuthentication
import CryptoSwift

/// Errors that can occur during wallet operations
enum WalletError: Error {
    case keyGenerationFailed
    case keyNotFound
    case authenticationFailed
    case invalidPublicKey
    case signatureFailed
    case invalidMessageEncoding
    case keychainError
    case secureEnclaveNotAvailable
    case biometricsNotAvailable
    case biometricsNotEnrolled
    
    var localizedDescription: String {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate wallet keys"
        case .keyNotFound:
            return "Wallet keys not found"
        case .authenticationFailed:
            return "Face ID authentication failed"
        case .invalidPublicKey:
            return "Invalid public key format"
        case .signatureFailed:
            return "Failed to sign message"
        case .invalidMessageEncoding:
            return "Invalid message encoding"
        case .keychainError:
            return "Failed to access Keychain"
        case .secureEnclaveNotAvailable:
            return "Secure Enclave not available on this device"
        case .biometricsNotAvailable:
            return "Face ID is not available on this device"
        case .biometricsNotEnrolled:
            return "Face ID is not set up on this device"
        }
    }
}

final class WalletKeyManager {
    
    // MARK: - Shared Instance
    
    static let shared = try! WalletKeyManager()
    
    // MARK: - Constants
    
    private enum Constants {
        static let privateKeyTag = "com.wallet.privatekey"
        static let publicKeyTag = "com.wallet.publickey"
    }
    
    // MARK: - Properties
    
    private let authContext = LAContext()
    private let accessControl: SecAccessControl
    
    // MARK: - Initialization
    
    init() throws {
        // Check Face ID availability first
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    throw WalletError.biometricsNotAvailable
                case LAError.biometryNotEnrolled.rawValue:
                    throw WalletError.biometricsNotEnrolled
                default:
                    throw WalletError.secureEnclaveNotAvailable
                }
            }
            throw WalletError.secureEnclaveNotAvailable
        }
        
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet, .privateKeyUsage],
            nil
        ) else {
            throw WalletError.secureEnclaveNotAvailable
        }
        self.accessControl = access
        self.authContext.localizedReason = "Authenticate to access your wallet"
    }
    
    // MARK: - Public Methods
    
    /// Generates a new P256 key pair in the Secure Enclave
    func createKeyPair() async throws {
        // First authenticate with Face ID
        try await withBiometricAuth(reason: "Authenticate to create wallet")
        
        // Remove any existing keys first
        try removeExistingKeys()
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Constants.privateKeyTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: accessControl,
                kSecUseAuthenticationContext as String: authContext
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw WalletError.keyGenerationFailed
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw WalletError.keyGenerationFailed
        }
        
        // Store public key reference in keychain for easier access
        let publicKeyAttributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Constants.publicKeyTag.data(using: .utf8)!,
            kSecValueRef as String: publicKey
        ]
        
        let status = SecItemAdd(publicKeyAttributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WalletError.keychainError
        }
    }
    
    /// Returns the Ethereum-compatible 64-byte raw public key
    func getPublicKey() async throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Constants.publicKeyTag.data(using: .utf8)!,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw WalletError.keyNotFound
        }
        
        let publicKey = item as! SecKey
        
        // Get raw representation of public key
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw WalletError.invalidPublicKey
        }
        
        // Convert from X.963 format to raw 64-byte format
        // X.963 format is: 0x04 || X || Y
        // We need just X || Y for Ethereum
        return publicKeyData.dropFirst() // Remove the 0x04 prefix
    }
    
    /// Returns the 42-character Ethereum checksum address (0x...)
    func getEthereumAddress() async throws -> String {
        let publicKeyData = try await getPublicKey()
        
        // Keccak-256 hash of public key
        let hash = publicKeyData.sha3(.keccak256)
        
        // Take last 20 bytes
        let address = hash.suffix(20)
        
        // Convert to checksum address
        return try toChecksumAddress(address)
    }
    
    /// Signs a UTF-8 message with Face ID authentication
    func signMessage(_ message: String) async throws -> Data {
        guard let messageData = message.data(using: .utf8) else {
            throw WalletError.invalidMessageEncoding
        }
        
        // Get private key reference with biometric authentication
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Constants.privateKeyTag.data(using: .utf8)!,
            kSecReturnRef as String: true,
            kSecUseOperationPrompt as String: "Authenticate to sign message",
            kSecUseAuthenticationContext as String: authContext
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            throw WalletError.keyNotFound
        }
        
        let privateKey = item as! SecKey
        
        // Sign the message
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            messageData as CFData,
            &error
        ) as Data? else {
            throw WalletError.signatureFailed
        }
        
        return signature
    }
    
    // MARK: - Private Methods
    
    private func removeExistingKeys() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Constants.privateKeyTag.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let publicQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Constants.publicKeyTag.data(using: .utf8)!
        ]
        
        SecItemDelete(publicQuery as CFDictionary)
    }
    
    private func toChecksumAddress(_ address: Data) throws -> String {
        let addressHex = address.map { String(format: "%02x", $0) }.joined()
        let hash = addressHex.data(using: .ascii)?.sha3(.keccak256)
        
        guard let hashHex = hash?.map({ String(format: "%02x", $0) }).joined() else {
            throw WalletError.invalidPublicKey
        }
        
        var result = "0x"
        
        for (i, char) in addressHex.enumerated() {
            let hashDigit = Int(String(hashHex[hashHex.index(hashHex.startIndex, offsetBy: i)]), radix: 16) ?? 0
            if hashDigit >= 8 {
                result.append(char.uppercased())
            } else {
                result.append(char.lowercased())
            }
        }
        
        return result
    }
    
    private func withBiometricAuth(reason: String) async throws {
        let context = LAContext()
        context.localizedReason = reason
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if !success {
                throw WalletError.authenticationFailed
            }
        } catch {
            throw WalletError.authenticationFailed
        }
    }
}
