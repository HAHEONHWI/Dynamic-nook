#ifndef SYSTEM_DISPLAY_BRIDGE_C_H
#define SYSTEM_DISPLAY_BRIDGE_C_H

#include <stdbool.h>
#include <stdint.h>

bool NookDisplaySupportsDDC(uint32_t displayID);
bool NookDisplayGetBrightness(uint32_t displayID, float *value);
bool NookDisplaySetBrightness(uint32_t displayID, float value);
bool NookDisplaySetContrast(uint32_t displayID, float value);

#endif
