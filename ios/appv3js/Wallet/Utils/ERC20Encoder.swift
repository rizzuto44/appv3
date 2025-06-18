import Foundation
import CryptoSwift
import BigInt

enum ERC20EncodingError: Error {
    case invalidAddress
    case encodingFailed
}

struct ERC20Encoder {
    /// The ERC20 transfer function selector (keccak256 of "transfer(address,uint256)")
    private static let transferSelector = "a9059cbb"
    
    /// Encodes an ERC20 transfer call
    /// - Parameters:
    ///   - to: Destination address (with or without 0x prefix)
    ///   - amount: Amount to transfer as BigUInt (in base units, e.g. wei)
    /// - Returns: ABI encoded data for the transfer call or nil if encoding fails
    static func encodeTransfer(to: String, amount: BigUInt) -> Data? {
        // Remove 0x prefix if present and ensure address is valid
        let cleanAddress = to.hasPrefix("0x") ? String(to.dropFirst(2)) : to
        guard cleanAddress.count == 40 else { return nil }
        
        // Create empty data buffer
        var data = Data()
        
        // 1. Add function selector
        let selectorString = transferSelector
        let selectorData = selectorString.data(using: .hexadecimal) ?? Data()
        guard !selectorData.isEmpty else { return nil }
        data.append(selectorData)
        
        // 2. Add padded address (32 bytes)
        guard let addressData = cleanAddress.data(using: .hexadecimal) else { return nil }
        let paddedAddress = Data(repeating: 0, count: 32 - addressData.count) + addressData
        data.append(paddedAddress)
        
        // 3. Add padded amount (32 bytes)
        let amountData = amount.serialize()
        let paddedAmount = Data(repeating: 0, count: 32 - amountData.count) + amountData
        data.append(paddedAmount)
        
        return data
    }
}

// Helper extension for BigUInt serialization
private extension BigUInt {
    func serialize() -> Data {
        let hex = String(self, radix: 16)
        let paddedHex = hex.count % 2 == 0 ? hex : "0" + hex
        return paddedHex.data(using: .hexadecimal) ?? Data()
    }
}

// Helper extension for hex encoding
private extension String.Encoding {
    static let hexadecimal = String.Encoding(rawValue: 0xFA1FA1)
}

private extension String {
    func data(using encoding: String.Encoding) -> Data? {
        guard encoding == .hexadecimal else { return self.data(using: encoding) }
        
        let hex = self.lowercased()
            .replacingOccurrences(of: "0x", with: "")
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = String(hex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        
        return data
    }
}
