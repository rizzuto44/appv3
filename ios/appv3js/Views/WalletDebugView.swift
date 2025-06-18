import SwiftUI
import BigInt

struct TransactionDebugInfo {
    var unsignedRLP: String = ""
    var signature: String = ""
    var v: String = ""
    var r: String = ""
    var s: String = ""
    var finalTx: String = ""
}

struct WalletDebugView: View {
    @State private var walletStatus = ""
    @State private var isCreating = false
    
    @State private var publicKey = ""
    @State private var isLoadingPublicKey = false
    
    @State private var ethAddress = ""
    @State private var isLoadingAddress = false
    
    @State private var messageToSign = ""
    @State private var signature = ""
    @State private var isSigningMessage = false
    
    @State private var rlpEncodedData = ""
    @State private var isTestingRLP = false
    
    @State private var signedTxData = ""
    @State private var isTestingSignedTx = false
    
    @State private var txInfo = TransactionDebugInfo()
    @State private var isTestingTx = false
    
    @State private var jsonRPCPayload = ""
    @State private var isTestingJSONRPC = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // MARK: - Wallet Section
                GroupBox("🔐 Wallet Management") {
                    VStack(spacing: 16) {
                        // Create Wallet Button
                        Button {
                            Task { await createWallet() }
                        } label: {
                            if isCreating {
                                ProgressView()
                            } else {
                                Text("Create Wallet")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isCreating)
                        
                        // Status
                        if !walletStatus.isEmpty {
                            Text(walletStatus)
                                .foregroundStyle(walletStatus.contains("Failed") ? .red : .green)
                        }
                        
                        // Public Key
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Public Key:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    Task { await getPublicKey() }
                                } label: {
                                    if isLoadingPublicKey {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .disabled(isLoadingPublicKey)
                            }
                            
                            if !publicKey.isEmpty {
                                Text(publicKey)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(publicKey.contains("Error") ? .red : .primary)
                            }
                        }
                        
                        // Ethereum Address
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Ethereum Address:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    Task { await getEthereumAddress() }
                                } label: {
                                    if isLoadingAddress {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .disabled(isLoadingAddress)
                            }
                            
                            if !ethAddress.isEmpty {
                                Text(ethAddress)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(ethAddress.contains("Error") ? .red : .primary)
                            }
                        }
                    }
                    .padding()
                }
                
                // MARK: - Message Signing
                GroupBox("✍️ Message Signing") {
                    VStack(spacing: 16) {
                        TextField("Message to sign", text: $messageToSign)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocorrectionDisabled()
                        
                        Button {
                            Task { await signMessage() }
                        } label: {
                            if isSigningMessage {
                                ProgressView()
                            } else {
                                Text("Sign Message")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSigningMessage || messageToSign.isEmpty)
                        
                        if !signature.isEmpty {
                            Text(signature)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(signature.contains("Error") ? .red : .primary)
                        }
                    }
                    .padding()
                }
                
                // MARK: - Transaction Testing
                GroupBox("🧪 Transaction Signing") {
                    VStack(spacing: 16) {
                        Button {
                            Task { await testSignedTransaction() }
                        } label: {
                            if isTestingTx {
                                ProgressView()
                            } else {
                                Text("Test Signed Transaction")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingTx)
                        
                        if !txInfo.unsignedRLP.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Group {
                                    TxInfoRow(title: "Unsigned Transaction", value: txInfo.unsignedRLP)
                                    
                                    if !txInfo.signature.isEmpty {
                                        TxInfoRow(title: "Signature", value: txInfo.signature)
                                    }
                                    
                                    if !txInfo.v.isEmpty {
                                        TxInfoRow(title: "v", value: txInfo.v)
                                        TxInfoRow(title: "r", value: txInfo.r)
                                        TxInfoRow(title: "s", value: txInfo.s)
                                    }
                                    
                                    if !txInfo.finalTx.isEmpty {
                                        TxInfoRow(title: "Final Signed Transaction", value: txInfo.finalTx)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // MARK: - JSON-RPC Testing
                GroupBox("🌐 JSON-RPC Payload") {
                    VStack(spacing: 16) {
                        Button {
                            Task { await testJSONRPCPayload() }
                        } label: {
                            if isTestingJSONRPC {
                                ProgressView()
                            } else {
                                Text("Test JSON-RPC Payload")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingJSONRPC)
                        
                        if !jsonRPCPayload.isEmpty {
                            Text(jsonRPCPayload)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundStyle(jsonRPCPayload.contains("Error") ? .red : .primary)
                                .multilineTextAlignment(.leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
    
    private func createWallet() async {
        isCreating = true
        do {
            try await WalletKeyManager.shared.createKeyPair()
            walletStatus = "Wallet created"
            // Clear other fields since we have a new wallet
            publicKey = ""
            ethAddress = ""
            signature = ""
            messageToSign = ""
        } catch {
            walletStatus = "Failed to create wallet: \(error.localizedDescription)"
        }
        isCreating = false
    }
    
    private func getPublicKey() async {
        isLoadingPublicKey = true
        do {
            let key = try await WalletKeyManager.shared.getPublicKey()
            publicKey = key.map { String(format: "%02x", $0) }.joined()
        } catch {
            publicKey = "Error: \(error.localizedDescription)"
        }
        isLoadingPublicKey = false
    }
    
    private func getEthereumAddress() async {
        isLoadingAddress = true
        do {
            ethAddress = try await WalletKeyManager.shared.getEthereumAddress()
        } catch {
            ethAddress = "Error: \(error.localizedDescription)"
        }
        isLoadingAddress = false
    }
    
    private func signMessage() async {
        isSigningMessage = true
        signature = ""
        
        do {
            let signatureData = try await WalletKeyManager.shared.signMessage(messageToSign)
            signature = signatureData.map { String(format: "%02x", $0) }.joined()
        } catch {
            signature = "Error: \(error.localizedDescription)"
        }
        
        isSigningMessage = false
    }
    
    private func testRLPEncoding() async {
        isTestingRLP = true
        defer { isTestingRLP = false }
        
        // Create a sample transaction
        let transaction = EthereumTransaction(
            nonce: 1,
            gasPrice: BigUInt(20000000000), // 20 Gwei
            gasLimit: BigUInt(21000),        // Standard ETH transfer
            to: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
            value: BigUInt(1000000000000000000), // 1 ETH
            data: Data(),                        // Empty for ETH transfer
            chainId: 1                           // Mainnet
        )
        
        do {
            let encoded = try transaction.rlpEncode()
            rlpEncodedData = "RLP Encoded (hex):\n" + encoded.map { String(format: "%02x", $0) }.joined()
        } catch {
            rlpEncodedData = "Error: \(error.localizedDescription)"
        }
    }
    
    private func testSignedTransaction() async {
        isTestingSignedTx = true
        defer { isTestingSignedTx = false }
        
        var output = ""
        
        do {
            // Create a sample transaction
            var transaction = EthereumTransaction(
                nonce: 1,
                gasPrice: BigUInt(20000000000), // 20 Gwei
                gasLimit: BigUInt(21000),        // Standard ETH transfer
                to: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
                value: BigUInt(1000000000000000000), // 1 ETH
                data: Data(),                        // Empty for ETH transfer
                chainId: 1                           // Mainnet
            )
            
            // Get the unsigned RLP encoded transaction
            let unsignedRLP = try transaction.rlpEncode()
            output += "Unsigned RLP:\n" + unsignedRLP.map { String(format: "%02x", $0) }.joined() + "\n\n"
            
            // Sign the transaction hash
            let signature = try await WalletKeyManager.shared.signMessage(unsignedRLP.map { String(format: "%02x", $0) }.joined())
            output += "Signature:\n" + signature.map { String(format: "%02x", $0) }.joined() + "\n\n"
            
            // For testing, apply dummy v,r,s values (proper extraction will come later)
            transaction.applySignature(
                v: BigUInt(37), // chainId * 2 + 35 (mainnet, even y-parity)
                r: BigUInt(1),  // dummy r value
                s: BigUInt(1)   // dummy s value
            )
            
            // Get the signed transaction
            let signedRLP = try transaction.rlpEncodedSignedTx()
            output += "Signed Transaction:\n" + signedRLP.map { String(format: "%02x", $0) }.joined()
            
            signedTxData = output
            
        } catch {
            signedTxData = "Error: \(error.localizedDescription)"
        }
    }
    
    private func testJSONRPCPayload() async {
        isTestingJSONRPC = true
        defer { isTestingJSONRPC = false }
        
        // Sample signed transaction hex (this would come from actual signing in production)
        let sampleSignedTx = "f86c808504a817c800825208942c283b75c9a53dbf3a4eb175bb9bab08437c5bc6880de0b6b3a764000080820150a0722939373dac5949e4aa76da096cd42ad145c50bc06bb10123cd50968877616da0684c13363914f3e43adbb594186f55f38f39fb8555799a7e4b9df5090ad783b8"
        
        do {
            let payloadData = try EthereumJSONRPC.constructSendRawTransactionPayload(signedTxHex: sampleSignedTx)
            if let jsonString = String(data: payloadData, encoding: .utf8) {
                jsonRPCPayload = jsonString
            } else {
                jsonRPCPayload = "Error: Could not decode JSON string"
            }
        } catch {
            jsonRPCPayload = "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Helper Views
struct TxInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

#Preview {
    WalletDebugView()
}
