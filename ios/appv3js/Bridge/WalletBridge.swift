import Foundation
import React
import ReactCommon

@objc(WalletBridge)
class WalletBridge: NSObject {
    
    @objc
    static func moduleName() -> String {
        return "WalletBridge"
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    @objc
    func createWallet(_ resolve: @escaping (Any?) -> Void,
                     rejecter reject: @escaping (String, String, Error?) -> Void) {
        // Implementation will come later
    }
    
    @objc
    func authenticateWithFaceID(_ resolve: @escaping (Any?) -> Void,
                               rejecter reject: @escaping (String, String, Error?) -> Void) {
        // Implementation will come later
    }
    
    @objc
    func signTransaction(_ transaction: String,
                        resolve: @escaping (Any?) -> Void,
                        rejecter reject: @escaping (String, String, Error?) -> Void) {
        // Implementation will come later
    }
}
