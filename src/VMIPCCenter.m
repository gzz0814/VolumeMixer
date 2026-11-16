//
//  VMIPCCenter.m
//

#import "VMIPCCenter.h"
#import <Foundation/Foundation.h>

// We keep a process-local registry of method handlers and broadcast calls via a
// distributed notification. Each injected process listens and, if it owns the
// targeted bundle id, runs its registered handler. This avoids a hard dependency
// on the third-party MRYIPC library while preserving the same fan-out semantics.
static NSMutableDictionary<NSString *, id (^)(NSDictionary *)> *gHandlers;
static NSMutableArray<VMIPCCenter *> *gInstances;

@interface VMIPCCenter ()
@property (nonatomic, copy) NSString *name;
@end

@implementation VMIPCCenter

+ (void)initialize {
    if (self == [VMIPCCenter class]) {
        gHandlers = [NSMutableDictionary dictionary];
        gInstances = [NSMutableArray array];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(_handleBroadcast:)
                   name:@"com.brend0n.volumemixer/ipc"
                 object:nil];
    }
}

+ (instancetype)centerWithName:(NSString *)name {
    VMIPCCenter *center = [[VMIPCCenter alloc] init];
    center.name = name;
    @synchronized (gInstances) {
        [gInstances addObject:center];
    }
    return center;
}

- (void)registerMethod:(NSString *)method withHandler:(id (^)(NSDictionary *))handler {
    @synchronized (gHandlers) {
        gHandlers[method] = handler;
    }
}

- (NSDictionary *)callRemoteMethod:(NSString *)method center:(NSString *)centerName args:(NSDictionary *)args {
    NSDictionary *payload = @{ @"method": method,
                               @"center": centerName ?: @"",
                               @"args": args ?: @{} };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.brend0n.volumemixer/ipc"
                                                        object:nil
                                                      userInfo:payload];
    return nil;
}

+ (void)_handleBroadcast:(NSNotification *)note {
    NSDictionary *payload = note.userInfo;
    NSString *method = payload[@"method"];
    if (!method) return;

    id (^)(NSDictionary *)handler = nil;
    @synchronized (gHandlers) {
        handler = gHandlers[method];
    }
    if (handler) {
        handler(payload[@"args"]);
    }
}

@end
