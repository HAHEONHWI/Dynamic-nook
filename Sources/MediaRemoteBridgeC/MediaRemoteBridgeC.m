#import "MediaRemoteBridgeC.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>

static const char *NCFrameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote";
static void *NCFrameworkHandle;

static bool NCEnsureFrameworkLoaded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NCFrameworkHandle = dlopen(NCFrameworkPath, RTLD_NOW | RTLD_GLOBAL);
    });
    return NCFrameworkHandle != NULL;
}

bool NCMediaRemoteIsAvailable(void) {
    if (!NCEnsureFrameworkLoaded()) return false;
    Class requestClass = NSClassFromString(@"MRNowPlayingRequest");
    return requestClass != Nil &&
        [requestClass respondsToSelector:NSSelectorFromString(@"localNowPlayingItem")] &&
        dlsym(NCFrameworkHandle, "MRMediaRemoteSendCommand") != NULL;
}

CFDictionaryRef NCMediaRemoteCopyNowPlayingInfo(void) {
    if (!NCEnsureFrameworkLoaded()) return NULL;

    @try {
        Class requestClass = NSClassFromString(@"MRNowPlayingRequest");
        SEL itemSelector = NSSelectorFromString(@"localNowPlayingItem");
        SEL pathSelector = NSSelectorFromString(@"localNowPlayingPlayerPath");
        if (requestClass == Nil || ![requestClass respondsToSelector:itemSelector]) return NULL;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id item = [requestClass performSelector:itemSelector];
        id playerPath = [requestClass respondsToSelector:pathSelector]
            ? [requestClass performSelector:pathSelector]
            : nil;
#pragma clang diagnostic pop
        NSDictionary *rawInfo = [item valueForKey:@"nowPlayingInfo"];
        if (![rawInfo isKindOfClass:[NSDictionary class]]) return NULL;

        NSMutableDictionary *info = [rawInfo mutableCopy];
        id client = [playerPath valueForKey:@"client"];
        NSString *displayName = [client valueForKey:@"displayName"];
        NSString *bundleIdentifier = [client valueForKey:@"bundleIdentifier"];
        if (displayName.length > 0) info[@"NookClonePlayerDisplayName"] = displayName;
        if (bundleIdentifier.length > 0) info[@"NookClonePlayerBundleIdentifier"] = bundleIdentifier;
        return CFBridgingRetain([info copy]);
    } @catch (__unused NSException *exception) {
        return NULL;
    }
}

bool NCMediaRemoteSendCommand(int32_t command) {
    if (!NCEnsureFrameworkLoaded()) return false;
    typedef Boolean (*SendCommandFunction)(int32_t, CFDictionaryRef _Nullable);
    SendCommandFunction function = (SendCommandFunction)dlsym(NCFrameworkHandle, "MRMediaRemoteSendCommand");
    if (function == NULL) return false;
    return function(command, NULL);
}

bool NCMediaRemoteSetElapsedTime(double elapsedTime) {
    if (!NCEnsureFrameworkLoaded()) return false;
    typedef void (*SetElapsedTimeFunction)(double);
    SetElapsedTimeFunction function = (SetElapsedTimeFunction)dlsym(NCFrameworkHandle, "MRMediaRemoteSetElapsedTime");
    if (function == NULL) return false;
    function(elapsedTime);
    return true;
}
