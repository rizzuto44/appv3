import Foundation
import BigInt

enum EthereumTransactionError: Error {
    case invalidAddress
    case invalidData
    case missingSignature
}

struct EthereumTransaction {
    let nonce: BigUInt
    let gasPrice: BigUInt
    let gasLimit: BigUInt
    let to: String
    let value: BigUInt
    let data: Data
    let chainId: BigUInt
    
    // Signature components
    private(set) var v: BigUInt?
    private(set) var r: BigUInt?
    private(set) var s: BigUInt?
    
    /// Validates if the transaction parameters are valid
    func validate() throws {
        // Check address format
        let addressRegex = try? NSRegularExpression(pattern: "^0x[0-9a-fA-F]{40}$")
        guard let addressRegex = addressRegex,
              addressRegex.firstMatch(in: to, range: NSRange(to.startIndex..., in: to)) != nil else {
            throw EthereumTransactionError.invalidAddress
        }
        
        // Basic sanity checks
        guard gasPrice > 0,
              gasLimit > 0,
              chainId > 0 else {
            throw EthereumTransactionError.invalidData
        }
    }
    
    /// RLP encodes the transaction for signing (EIP-155)
    func rlpEncode() throws -> Data {
        try validate()
        
        // Prepare transaction fields in correct order for unsigned tx
        let fields: [Any] = [
            nonce,      // uint
            gasPrice,   // uint
            gasLimit,   // uint
            to,        // address (20 bytes)
            value,     // uint
            data,      // binary
            chainId,   // uint
            BigUInt(0), // v (empty)
            BigUInt(0)  // r, s (empty)
        ]
        
        // RLP encode the transaction
        return try RLP.encodeList(fields)
    }
    
    /// Apply signature components to the transaction
    mutating func applySignature(v: BigUInt, r: BigUInt, s: BigUInt) {
        self.v = v
        self.r = r
        self.s = s
    }
    
    /// RLP encodes the signed transaction (for broadcasting)
    func rlpEncodedSignedTx() throws -> Data {
        // Ensure we have signature components
        guard let v = v, let r = r, let s = s else {
            throw EthereumTransactionError.missingSignature
        }
        
        try validate()
        
        // Prepare transaction fields in correct order for signed tx
        let fields: [Any] = [
            nonce,    // uint
            gasPrice, // uint
            gasLimit, // uint
            to,      // address (20 bytes)
            value,   // uint
            data,    // binary
            v,       // uint
            r,       // uint
            s        // uint
        ]
        
        // RLP encode the complete signed transaction
        return try RLP.encodeList(fields)
    }
}

// MARK: - CustomStringConvertible
extension EthereumTransaction: CustomStringConvertible {
    var description: String {
        let base = """
        Transaction:
          To: \(to)
          Value: \(value) Wei
          Nonce: \(nonce)
          Gas Price: \(gasPrice) Wei
          Gas Limit: \(gasLimit)
          Chain ID: \(chainId)
          Data: \(data.map { String(format: "%02x", $0) }.joined())
        """
        
        if let v = v, let r = r, let s = s {
            return base + """
            
              Signature:
                v: \(v)
                r: \(r)
                s: \(s)
            """
        }
        
        return base
    }
}
