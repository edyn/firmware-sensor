#include "mbed.h"
#include <stdio.h>

// enable to turn on debug prints and AT commands
// #define DEBUG_MAC 1

#ifdef DEBUG_MAC
    #define MTS_RADIO_DEBUG_COMMANDS 1
    #define DEBUG_PRINTF(fmt, args...)  printf("%s:%d: "fmt, __FUNCTION__, __LINE__, ## args)
#else
    #define DEBUG_PRINTF(fmt, args...)
#endif
