# Rumble ANE Project Documentation

## Overview

The Rumble ANE (Adobe Native Extension) provides vibration (rumble) functionality for Adobe AIR applications on Windows. It supports XInput-compatible controllers (Xbox controllers).

## Project Structure

### Root Directory (`ane/rumble/`)

- `build.ps1`: PowerShell build script that compiles native DLLs and packages the ANE.
- `packaging/`: Contains ANE packaging files, extension metadata, and build artifacts.
- `src-as3/`: ActionScript 3 source code for the extension API.
- `src-native/`: C++ native code for Windows implementation.

## Source Code Locations

### ActionScript 3 API (`src-as3/com/mcleodgaming/ane/rumble/Rumble.as`)

This file provides the AS3 interface to the native extension.

**Key Functions:**

- `initialize()`: Initializes the extension and enumerates connected controllers.
- `setRumble(xinputIndex, left, right, durationMs)`: Sets vibration for XInput controllers.
- `identifyActiveControllers()`: Returns JSON object with active controller information.
- `stopAll()`: Stops vibration on all controllers.
- `shutdown()`: Cleans up resources and stops all vibration.

### Native C++ Implementation (`src-native/`)

- `RumbleANE.h`: Header file with structures and function declarations.
- `RumbleANE.cpp`: Main implementation file.

**Key Components:**

- **Device Registry**: Global `DeviceRegistry` struct tracks XInput devices.
- **FRE Functions**: Flash Runtime Extensions functions that bridge AS3 calls to native code.
- **XInput Integration**: Uses Windows XInput API for controller vibration.

## Build Process

1. **Compile Native DLLs**: `build.ps1` uses MSBuild to compile `RumbleANE.vcxproj` for both x86 and x64 architectures.
2. **Package SWC**: Compiles AS3 code into a SWC library using Adobe AIR SDK's `compc`.
3. **Create ANE**: Uses Adobe AIR SDK's `adt` tool to package the extension with platform-specific DLLs.

## Usage in AIR Applications

```actionscript
import com.mcleodgaming.ane.rumble.Rumble;

// Initialize
if (Rumble.initialize()) {
    // Set rumble on controller 0, left motor 50%, right motor 75%, for 500ms
    Rumble.setRumble(0, 0.5, 0.75, 500);

    // Stop all vibration
    Rumble.stopAll();

    // Cleanup
    Rumble.shutdown();
}
```

## Dependencies

- Adobe AIR SDK (for AS3 compilation and ANE packaging)
- Microsoft Visual Studio Build Tools (for C++ compilation)
- Windows XInput library (included via `#pragma comment(lib, "XInput.lib")`)

## Current Status

- ✅ XInput controller support (Xbox controllers)
- ✅ Windows x86 and x64 builds
- ✅ ANE packaging

## Troubleshooting

- Ensure AIR SDK path is correctly set in `build.ps1`
- Verify Visual Studio Build Tools are installed
- Check that XInput-compatible controllers are connected for testing</content>
  <parameter name="filePath">c:\Users\glwex\Documents\GitHub\ssf2-idk-140x-original\src\Super Smash Flash 2 Beta v1.4.0.1\ane\rumble\README.md
