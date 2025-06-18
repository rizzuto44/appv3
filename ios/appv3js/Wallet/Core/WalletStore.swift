import Foundation
import SwiftUI

@MainActor
final class WalletStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var ethereumAddress: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    
    // MARK: - Public Methods
    
    /// Creates a new wallet and retrieves its Ethereum address
    func createWallet() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // First create the wallet
            try await WalletKeyManager.shared.createKeyPair()
            
            // Then get its address
            let address = try await WalletKeyManager.shared.getEthereumAddress()
            
            // Basic Ethereum address validation (0x prefix + 40 hex chars)
            if address.hasPrefix("0x") && address.count == 42 {
                ethereumAddress = address
            } else {
                throw WalletError.invalidPublicKey
            }
            
        } catch {
            errorMessage = error.localizedDescription
            ethereumAddress = nil
        }
        
        isLoading = false
    }
}
