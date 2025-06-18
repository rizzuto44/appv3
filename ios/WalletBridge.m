#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(WalletBridge, NSObject)

RCT_EXTERN_METHOD(createWallet: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(authenticateWithFaceID: (RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(signTransaction: (NSString *)transaction
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end