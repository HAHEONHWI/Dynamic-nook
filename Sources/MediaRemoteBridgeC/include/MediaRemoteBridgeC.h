#ifndef MediaRemoteBridgeC_h
#define MediaRemoteBridgeC_h

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>

CF_ASSUME_NONNULL_BEGIN

// Private API:
// This bridge relies on MediaRemote. It may require maintenance after macOS updates.
bool NCMediaRemoteIsAvailable(void);
CFDictionaryRef _Nullable NCMediaRemoteCopyNowPlayingInfo(void) CF_RETURNS_RETAINED;
bool NCMediaRemoteSendCommand(int32_t command);
bool NCMediaRemoteSetElapsedTime(double elapsedTime);

CF_ASSUME_NONNULL_END

#endif
