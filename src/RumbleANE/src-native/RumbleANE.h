#pragma once
#include <vector>
#include <string>
#include <mutex>
#include <windows.h>

// Adobe AIR - Flash Runtime Extensions header
#include "FlashRuntimeExtensions.h"

/**
 * Rumble ANE (Adobe Native Extension) - Native C++ Implementation
 *
 * Provides controller vibration support for Adobe AIR applications on Windows.
 * Supports XInput-compatible controllers (Xbox).
 *
 * This header defines the core structures and function declarations for the native
 * implementation that bridges AS3 calls to Windows controller APIs.
 */

// Simple registry structures for tracking connected controllers

/**
 * Represents an XInput-compatible controller device
 */
struct XInputDevice {
    int index;              // XInput controller index (0-3, as used by XInputGetState)
};

/**
 * Global registry of all connected controller devices
 * Thread-safe for concurrent access from multiple threads
 */
struct DeviceRegistry {
    std::vector<XInputDevice> xinput;     // Connected XInput devices
    std::mutex mtx;                       // Mutex for thread-safe access
};

// Global device registry instance
extern DeviceRegistry g_registry;

// FRE (Flash Runtime Extensions) lifecycle functions
// These are called by the AIR runtime to initialize/finalize the extension

/**
 * Extension context initializer
 * Called when the extension context is created in AS3
 * Sets up the function table for AS3-to-native calls
 */
extern "C" {
    __declspec(dllexport) void RumbleContextInitializer(
        void* extData,                          // Extension data (unused)
        const uint8_t* ctxType,                 // Context type (unused)
        FREContext ctx,                         // FRE context for this extension instance
        uint32_t* numFunctions,                 // Output: number of functions
        const FRENamedFunction** functions      // Output: function table
    );

    /**
     * Extension context finalizer
     * Called when the extension context is disposed in AS3
     * Performs cleanup for this context
     */
    __declspec(dllexport) void RumbleContextFinalizer(FREContext ctx);
}

// FRE function declarations
// These functions are exposed to AS3 and handle the actual controller operations

/**
 * Initialize the extension and enumerate controllers
 * AS3: Rumble.initialize()
 */
FREObject fr_initialize(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]);

/**
 * Set vibration on an XInput controller
 * AS3: Rumble.setRumble(xinputIndex, left, right, durationMs)
 */
FREObject fr_setRumble(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]);

/**
 * Get information about active controllers
 * AS3: Rumble.identifyActiveControllers()
 */
FREObject fr_identifyActiveControllers(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]);

/**
 * Get the current state of an XInput controller
 * AS3: Rumble.getControllerState(xinputIndex)
 */
FREObject fr_getControllerState(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]);

/**
 * Stop vibration on all controllers
 * AS3: Rumble.stopAll()
 */
FREObject fr_stopAll(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]);

/**
 * Shutdown the extension and clean up resources
 * AS3: Rumble.shutdown()
 */
FREObject fr_shutdown(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]);
