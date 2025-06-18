import SwiftUI

struct WalletView: View {
    @StateObject private var store = WalletStore()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                
                // Welcome Section
                VStack(spacing: 8) {
                    Text("Welcome to your Ethereum Wallet")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                    
                    Text("Secure your wallet with Face ID")
                        .foregroundStyle(.secondary)
                }
                
                // Wallet Status Section
                if let address = store.ethereumAddress {
                    VStack(spacing: 8) {
                        Text("Your Ethereum Address:")
                            .fontWeight(.medium)
                        
                        Text(address)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                }
                
                Spacer()
                
                // Error Message
                if let error = store.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                // Create Wallet Button
                Button {
                    Task {
                        await store.createWallet()
                    }
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.white)
                    } else {
                        Text(store.ethereumAddress == nil ? "Create Wallet" : "Create New Wallet")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoading)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Ethereum Wallet")
        }
    }
}

#Preview {
    WalletView()
}