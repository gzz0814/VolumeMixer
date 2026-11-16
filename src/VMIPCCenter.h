//
//  VMIPCCenter.h
//  Thin wrapper over the per-process XPC center used to fan volume changes out
//  to every injected process. Mirrors the original MRYIPCCenter design so the
//  owning app applies the volume locally (only a process can set its own audio
//  session volume). Falls back to a plain NSXPCConnection-free broadcast via
//  distributed notifications when the peer is unavailable.
//

#import <Foundation/Foundation.h>

@interface VMIPCCenter : NSObject

+ (instancetype)centerWithName:(NSString *)name;

/// Register a handler for a named method. `handler` receives the argument dict
/// and must return a reply dict (may be nil).
- (void)registerMethod:(NSString *)method withHandler:(id (^)(NSDictionary *args))handler;

/// Call a remote method on the process owning `centerName`, returning its reply.
- (NSDictionary *)callRemoteMethod:(NSString *)method center:(NSString *)centerName args:(NSDictionary *)args;

@end
