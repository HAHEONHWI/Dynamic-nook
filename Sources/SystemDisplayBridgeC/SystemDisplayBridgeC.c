#include "SystemDisplayBridgeC.h"

#include <CoreGraphics/CGDisplayConfiguration.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <IOKit/i2c/IOI2CInterface.h>
#include <dlfcn.h>
#include <dispatch/dispatch.h>

// Private/low-level API:
// This implementation relies on direct IOKit DDC/CI transport and the deprecated
// CGDisplayIOServicePort bridge. It may require maintenance after macOS updates.

static float NookClamp(float value) {
    if (value < 0.0f) return 0.0f;
    if (value > 1.0f) return 1.0f;
    return value;
}

typedef int32_t (*NookDisplayServicesGetBrightnessFn)(uint32_t, float *);
typedef int32_t (*NookDisplayServicesSetBrightnessFn)(uint32_t, float);

static void *NookDisplayServicesHandle(void) {
    static void *handle = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

static bool NookDisplayServicesGetBrightness(uint32_t displayID, float *value) {
    void *handle = NookDisplayServicesHandle();
    if (handle == NULL) return false;
    NookDisplayServicesGetBrightnessFn function = (NookDisplayServicesGetBrightnessFn)dlsym(handle, "DisplayServicesGetBrightness");
    return function != NULL && function(displayID, value) == 0;
}

static bool NookDisplayServicesSetBrightness(uint32_t displayID, float value) {
    void *handle = NookDisplayServicesHandle();
    if (handle == NULL) return false;
    NookDisplayServicesSetBrightnessFn function = (NookDisplayServicesSetBrightnessFn)dlsym(handle, "DisplayServicesSetBrightness");
    return function != NULL && function(displayID, value) == 0;
}

static bool NookSetVCP(uint32_t displayID, uint8_t code, uint16_t value) {
    io_service_t framebuffer = CGDisplayIOServicePort(displayID);
    if (framebuffer == MACH_PORT_NULL) return false;

    IOItemCount count = 0;
    if (IOFBGetI2CInterfaceCount(framebuffer, &count) != kIOReturnSuccess || count == 0) {
        return false;
    }

    uint8_t message[7] = {
        0x51, 0x84, 0x03, code,
        (uint8_t)(value >> 8), (uint8_t)(value & 0xFF), 0
    };
    message[6] = 0x6E;
    for (int index = 0; index < 6; index++) message[6] ^= message[index];

    for (IOOptionBits bus = 0; bus < count; bus++) {
        io_service_t interface = MACH_PORT_NULL;
        if (IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface) != kIOReturnSuccess) continue;

        IOI2CConnectRef connection = NULL;
        IOReturn openResult = IOI2CInterfaceOpen(interface, kNilOptions, &connection);
        IOObjectRelease(interface);
        if (openResult != kIOReturnSuccess || connection == NULL) continue;

        IOI2CRequest request = {0};
        request.sendAddress = 0x6E;
        request.sendTransactionType = kIOI2CSimpleTransactionType;
        request.sendBuffer = (vm_address_t)message;
        request.sendBytes = sizeof(message);
        IOReturn result = IOI2CSendRequest(connection, kNilOptions, &request);
        IOI2CInterfaceClose(connection, kNilOptions);
        if (result == kIOReturnSuccess && request.result == kIOReturnSuccess) return true;
    }
    return false;
}

bool NookDisplaySupportsDDC(uint32_t displayID) {
    io_service_t framebuffer = CGDisplayIOServicePort(displayID);
    if (framebuffer == MACH_PORT_NULL) return false;
    IOItemCount count = 0;
    return IOFBGetI2CInterfaceCount(framebuffer, &count) == kIOReturnSuccess && count > 0;
}

bool NookDisplayGetBrightness(uint32_t displayID, float *value) {
    if (value == NULL) return false;
    // Private API: This implementation relies on DisplayServices. It may require
    // maintenance after macOS updates. All symbols are resolved at runtime.
    if (NookDisplayServicesGetBrightness(displayID, value)) {
        *value = NookClamp(*value);
        return true;
    }
    io_service_t framebuffer = CGDisplayIOServicePort(displayID);
    if (framebuffer == MACH_PORT_NULL) return false;
    io_service_t display = IODisplayForFramebuffer(framebuffer, kNilOptions);
    if (display == MACH_PORT_NULL) return false;
    float result = 0.0f;
    IOReturn status = IODisplayGetFloatParameter(display, kNilOptions, CFSTR("brightness"), &result);
    IOObjectRelease(display);
    if (status != kIOReturnSuccess) return false;
    *value = NookClamp(result);
    return true;
}

bool NookDisplaySetBrightness(uint32_t displayID, float value) {
    value = NookClamp(value);
    // Private API: runtime-loaded fallback for Apple displays on modern macOS.
    if (NookDisplayServicesSetBrightness(displayID, value)) return true;
    io_service_t framebuffer = CGDisplayIOServicePort(displayID);
    if (framebuffer != MACH_PORT_NULL) {
        io_service_t display = IODisplayForFramebuffer(framebuffer, kNilOptions);
        if (display != MACH_PORT_NULL) {
            IOReturn status = IODisplaySetFloatParameter(display, kNilOptions, CFSTR("brightness"), value);
            IOObjectRelease(display);
            if (status == kIOReturnSuccess) return true;
        }
    }
    return NookSetVCP(displayID, 0x10, (uint16_t)(value * 100.0f));
}

bool NookDisplaySetContrast(uint32_t displayID, float value) {
    return NookSetVCP(displayID, 0x12, (uint16_t)(NookClamp(value) * 100.0f));
}
