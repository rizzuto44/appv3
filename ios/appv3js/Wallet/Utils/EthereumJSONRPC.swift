import Foundation

enum EthereumJSONRPCError: Error {
    case invalidHexString
    case jsonEncodingFailed
}

struct EthereumJSONRPC {
    /// Constructs a JSON-RPC payload for eth_sendRawTransaction
    /// - Parameter signedTxHex: The hex string of the signed transaction (with or without 0x prefix)
    /// - Returns: JSON encoded Data ready for HTTP request
    /// - Throws: EthereumJSONRPCError if hex format is invalid or JSON encoding fails
    static func constructSendRawTransactionPayload(signedTxHex: String) throws -> Data {
        // Validate hex string format
        let cleanHex = signedTxHex.hasPrefix("0x") ? String(signedTxHex.dropFirst(2)) : signedTxHex
        
        // Ensure it's valid hex
        guard cleanHex.allSatisfy({ $0.isHexDigit }) else {
            throw EthereumJSONRPCError.invalidHexString
        }
        
        // Construct the payload
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_sendRawTransaction",
            "params": ["0x\(cleanHex)"],
            "id": 1
        ]
        
        // Try to encode to JSON
        do {
            return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        } catch {
            throw EthereumJSONRPCError.jsonEncodingFailed
        }
    }
}