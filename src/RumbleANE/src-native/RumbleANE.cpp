#define XINPUT_USE_1_4
#include "RumbleANE.h"
#include <xinput.h>
#include <sstream>

#pragma comment(lib, "XInput.lib")

// Global device registry instance
DeviceRegistry g_registry;

/**
 * Helper function to create FRE Boolean object
 */
static FREObject makeBoolean(bool v) {
    FREObject obj;
    FRENewObjectFromBool(v ? 1 : 0, &obj);
    return obj;
}

/**
 * Helper function to create FRE String object from std::string
 */
static FREObject makeString(const std::string& s) {
    FREObject obj;
    FRENewObjectFromUTF8((uint32_t)s.size(), (const uint8_t*)s.c_str(), &obj);
    return obj;
}

// FRE Extension lifecycle functions
extern "C" {
    /**
     * Initialize the extension context
     * Called by AIR when the extension is loaded
     * Sets up the function table that maps AS3 function calls to native functions
     */
    __declspec(dllexport) void RumbleContextInitializer(void* extData, const uint8_t* ctxType, FREContext ctx, uint32_t* numFunctions, const FRENamedFunction** functions) {
        // Define the function table - maps AS3 function names to native C++ functions
        static FRENamedFunction fn[] = {
            { (const uint8_t*)"initialize", NULL, fr_initialize },
            { (const uint8_t*)"setRumble", NULL, fr_setRumble },
            { (const uint8_t*)"identifyActiveControllers", NULL, fr_identifyActiveControllers },
            { (const uint8_t*)"getControllerState", NULL, fr_getControllerState },
            { (const uint8_t*)"stopAll", NULL, fr_stopAll },
            { (const uint8_t*)"shutdown", NULL, fr_shutdown },
        };

        // Return the function table to AIR
        *numFunctions = sizeof(fn)/sizeof(FRENamedFunction);
        *functions = fn;
    }

    /**
     * Finalize the extension context
     * Called by AIR when the extension context is disposed
     */
    __declspec(dllexport) void RumbleContextFinalizer(FREContext ctx) {
        // Cleanup handled in fr_shutdown
    }

    /**
     * Required by AIR: Extension initializer that bridges to our context initializer
     */
    __declspec(dllexport) void FREExtensionInitializer(void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet) {
        *extDataToSet = nullptr;
        *ctxInitializerToSet = RumbleContextInitializer;
        *ctxFinalizerToSet = RumbleContextFinalizer;
    }

    /**
     * Required by AIR: Extension finalizer
     */
    __declspec(dllexport) void FREExtensionFinalizer(void* extData) {
        // no-op
    }
}

/**
 * Enumerate all connected XInput controllers
 * Updates the global device registry with currently connected controllers
 */
static void enumerateXInput() {
    std::lock_guard<std::mutex> lock(g_registry.mtx);
    g_registry.xinput.clear();
    XINPUT_STATE state; ZeroMemory(&state, sizeof(XINPUT_STATE));
    for (int i=0; i<4; ++i) {
        if (XInputGetState(i, &state) == ERROR_SUCCESS) {
            g_registry.xinput.push_back({ i });
        }
    }
}

/**
 * FRE function: Initialize the extension
 * AS3: Rumble.initialize()
 *
 * Enumerates connected controllers and prepares for rumble operations.
 *
 * @param ctx - FRE context
 * @param funcData - Function data (unused)
 * @param argc - Argument count (should be 0)
 * @param argv - Arguments (none expected)
 * @return FREObject - Boolean true on success
 */
FREObject fr_initialize(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    enumerateXInput();
    return makeBoolean(true);
}

/**
 * FRE function: Set rumble on XInput controller
 * AS3: Rumble.setRumble(xinputIndex, left, right, durationMs)
 *
 * Sets vibration motors on the specified XInput controller.
 * If duration > 0, starts a detached thread to stop vibration after the specified time.
 *
 * @param ctx - FRE context
 * @param funcData - Function data (unused)
 * @param argc - Argument count (should be 4)
 * @param argv - Arguments: [int index, double left, double right, int duration]
 * @return FREObject - Boolean true on success
 */
FREObject fr_setRumble(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    // Extract arguments from AS3
    int32_t idx = 0; double left = 0.0, right = 0.0; int32_t dur = 0;
    FREGetObjectAsInt32(argv[0], &idx);
    FREGetObjectAsDouble(argv[1], &left);
    FREGetObjectAsDouble(argv[2], &right);
    FREGetObjectAsInt32(argv[3], &dur);

    // Set vibration using XInput API
    // Convert 0.0-1.0 range to 0-65535 range
    XINPUT_VIBRATION vib;
    vib.wLeftMotorSpeed = (WORD)(left * 65535.0);
    vib.wRightMotorSpeed = (WORD)(right * 65535.0);
    DWORD result = XInputSetState(idx, &vib);

    if (result != ERROR_SUCCESS) {
        // Return false on failure
        return makeBoolean(false);
    }

    // Handle duration-based automatic stop
    if (dur > 0) {
        // Start detached thread to stop vibration after duration
        // This prevents blocking the main thread
        std::thread([idx, dur]{
            Sleep(dur);
            XINPUT_VIBRATION zero; zero.wLeftMotorSpeed = 0; zero.wRightMotorSpeed = 0;
            DWORD stopResult = XInputSetState(idx, &zero);
            if (stopResult != ERROR_SUCCESS) {
                // Ignore stop failure for now
            }
        }).detach();
    }

    return makeBoolean(true);
}

/**
 * FRE function: Identify active controllers
 * AS3: Rumble.identifyActiveControllers()
 *
 * Returns JSON string with information about connected controllers.
 * Used for debugging and controller enumeration.
 *
 * @param ctx - FRE context
 * @param funcData - Function data (unused)
 * @param argc - Argument count (should be 0)
 * @param argv - Arguments (none expected)
 * @return FREObject - String containing JSON controller information
 */
FREObject fr_identifyActiveControllers(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    enumerateXInput(); // Refresh XInput device list

    std::lock_guard<std::mutex> lock(g_registry.mtx);

    // Return as ActionScript array
    FREObject arr = NULL;
    FRENewObject((const uint8_t*)"Array", 0, NULL, &arr, NULL);

    for (size_t i = 0; i < g_registry.xinput.size(); ++i) {
        const auto& dev = g_registry.xinput[i];
        FREObject num;
        FRENewObjectFromInt32(dev.index, &num);
        FRESetArrayElementAt(arr, i, num);
    }

    return arr;
}

/**
 * FRE function: Get the current state of an XInput controller
 * AS3: Rumble.getControllerState(index)
 *
 * Returns button states for controller detection.
 *
 * @param ctx - FRE context
 * @param funcData - Function data (unused)
 * @param argc - Argument count (should be 1)
 * @param argv - Arguments: [xinputIndex]
 * @return FREObject - Object with buttons field, or null if failed
 */
FREObject fr_getControllerState(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    if (argc < 1) return NULL;

    uint32_t index;
    FREGetObjectAsUint32(argv[0], &index);

    XINPUT_STATE state;
    if (XInputGetState(index, &state) != ERROR_SUCCESS) {
        return NULL;
    }

    FREObject obj = NULL;
    FRENewObject((const uint8_t*)"Object", 0, NULL, &obj, NULL);

    // Add buttons as uint32
    FREObject buttons;
    FRENewObjectFromUint32(state.Gamepad.wButtons, &buttons);
    FRESetObjectProperty(obj, (const uint8_t*)"buttons", buttons, NULL);

    return obj;
}

/**
 * FRE function: Stop all controller vibration
 * AS3: Rumble.stopAll()
 *
 * Immediately stops vibration on all connected controllers.
 *
 * @param ctx - FRE context
 * @param funcData - Function data (unused)
 * @param argc - Argument count (should be 0)
 * @param argv - Arguments (none expected)
 * @return FREObject - Boolean true on success
 */
FREObject fr_stopAll(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    std::lock_guard<std::mutex> lock(g_registry.mtx);

    // Stop all XInput controllers
    for (auto& d : g_registry.xinput) {
        XINPUT_VIBRATION z; z.wLeftMotorSpeed = 0; z.wRightMotorSpeed = 0;
        XInputSetState(d.index, &z);
    }

    return makeBoolean(true);
}

/**
 * FRE function: Shutdown the extension
 * AS3: Rumble.shutdown()
 *
 * Stops all vibration and cleans up resources.
 * Should be called before application exit.
 *
 * @param ctx - FRE context
 * @param funcData - Function data (unused)
 * @param argc - Argument count (should be 0)
 * @param argv - Arguments (none expected)
 * @return FREObject - Boolean true on success
 */
FREObject fr_shutdown(FREContext ctx, void* funcData, uint32_t argc, FREObject argv[]) {
    fr_stopAll(ctx, funcData, 0, nullptr); // Stop all vibration first

    std::lock_guard<std::mutex> lock(g_registry.mtx);

    // Clear device registries
    g_registry.xinput.clear();

    return makeBoolean(true);
}
