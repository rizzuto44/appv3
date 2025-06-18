import Foundation
import BigInt

/// RLP (Recursive Length Prefix) encoding implementation
enum RLP {
    /// RLP encoding error types
    enum Error: Swift.Error {
        case invalidAddress
        case invalidData
        case invalidLength
    }
    
    /// Encode a single value
    static func encode(_ value: Any) throws -> Data {
        switch value {
        case let int as BigUInt:
            return encodeInteger(int)
        case let string as String:
            if string.hasPrefix("0x") {
                return try encodeAddress(string)
            }
            return encodeString(string)
        case let data as Data:
            return encodeData(data)
        case let array as [Any]:
            return try encodeList(array)
        default:
            throw Error.invalidData
        }
    }
    
    /// Encode a list of items
    static func encodeList(_ items: [Any]) throws -> Data {
        var concatenated = Data()
        for item in items {
            concatenated.append(try encode(item))
        }
        
        let length = concatenated.count
        if length == 0 {
            return Data([0xc0])
        } else if length <= 55 {
            return Data([UInt8(0xc0 + length)]) + concatenated
        } else {
            let lengthData = encodeLengthPrefix(length)
            return Data([UInt8(0xf7 + lengthData.count)]) + lengthData + concatenated
        }
    }
    
    // MARK: - Private Helpers
    
    private static func encodeInteger(_ value: BigUInt) -> Data {
        if value == 0 {
            return Data([0x80])
        }
        
        let data = value.serialize()
        if data.count == 1 && data[0] < 0x80 {
            return data
        }
        return encodeData(data)
    }
    
    private static func encodeAddress(_ hex: String) throws -> Data {
        let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard stripped.count == 40 else { throw Error.invalidAddress }
        
        if let data = stripped.data(using: .hexadecimal) {
            return encodeData(data)
        } else {
            throw Error.invalidData
        }
    }
    
    private static func encodeString(_ string: String) -> Data {
        let data = string.data(using: .utf8) ?? Data()
        return encodeData(data)
    }
    
    private static func encodeData(_ data: Data) -> Data {
        if data.count == 1 && data[0] < 0x80 {
            return data
        } else if data.count <= 55 {
            return Data([UInt8(0x80 + data.count)]) + data
        } else {
            let lengthData = encodeLengthPrefix(data.count)
            return Data([UInt8(0xb7 + lengthData.count)]) + lengthData + data
        }
    }
    
    private static func encodeLengthPrefix(_ length: Int) -> Data {
        var len = length
        var result = Data()
        while len > 0 {
            result.insert(UInt8(len & 0xFF), at: 0)
            len >>= 8
        }
        return result
    }
}

// MARK: - String Hex Encoding
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

private extension String.Encoding {
    static let hexadecimal = String.Encoding(rawValue: 0xFA1FA1)
}

// MARK: - BigUInt Helper
private extension BigUInt {
    func serialize() -> Data {
        let hex = String(self, radix: 16)
        let paddedHex = hex.count % 2 == 0 ? hex : "0" + hex
        return paddedHex.data(using: .hexadecimal) ?? Data()
    }
}
