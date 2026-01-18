# RumbleANE Folder Structure and File Explanations

This document provides a comprehensive explanation of every file and folder within the RumbleANE directory, detailing their purpose, contents, and why they are needed for the Adobe Native Extension (ANE) that provides controller rumble functionality.

## Root Directory Files

### `build.ps1`

**Purpose**: PowerShell build script that automates the entire compilation and packaging process for the ANE.

**Why it's needed**:

- Compiles C++ native code for both x86 and x64 architectures using MSBuild
- Packages the compiled DLLs into the final ANE file using Adobe AIR SDK tools
- Handles SWC compilation from ActionScript 3 source code
- Provides a single command to build the entire extension
- Includes error checking and logging for troubleshooting build issues

### `README.md`

**Purpose**: Comprehensive documentation explaining the RumbleANE project structure, build process, and usage.

**Why it's needed**:

- Provides overview of the extension's capabilities and architecture
- Documents the build process and dependencies
- Contains usage examples for developers integrating the ANE
- Includes troubleshooting information for common issues

## `packaging/` Directory

### `extension.xml`

**Purpose**: XML configuration file that defines the ANE's metadata, supported platforms, and native library mappings.

**Why it's needed**:

- Tells Adobe AIR which native libraries to load for each platform
- Specifies the extension ID that AS3 code uses to create the extension context
- Defines initializer and finalizer functions for proper lifecycle management
- Required by the AIR SDK's ADT tool for ANE packaging

### `ane-cert.p12`

**Purpose**: Code signing certificate used to sign the ANE package.

**Why it's needed**:

- Required by Adobe AIR for security when loading native extensions
- Ensures the ANE comes from a trusted source
- Prevents tampering with the extension binaries
- Mandatory for ANE installation in production AIR applications

### `package_ane.ps1`

**Purpose**: PowerShell script that handles the final ANE packaging step using Adobe AIR SDK tools.

**Why it's needed**:

- Automates the complex ADT command-line packaging process
- Combines SWC, native libraries, and metadata into the final .ane file
- Handles platform-specific library inclusion
- Provides error checking for packaging failures

### `RumbleANE.swc`

**Purpose**: Compiled ActionScript 3 library containing the extension's AS3 API.

**Why it's needed**:

- Contains the compiled bytecode for the Rumble.as class
- Required by ADT for packaging into the final ANE
- Provides the interface that AIR applications use to call native functions
- Must be included in the ANE for the extension to work

### `RumbleANE.ane`

**Purpose**: The final packaged Adobe Native Extension file ready for distribution.

**Why it's needed**:

- This is the actual file that gets included in AIR application builds
- Contains all platform binaries, AS3 code, and metadata in a single package
- Can be distributed to developers for integration into their AIR projects
- The file that users add to their AIR application's extension directory

## `src-as3/` Directory

### `com/masterwex/ane/rumble/Rumble.as`

**Purpose**: ActionScript 3 source code that provides the API interface for the native extension.

**Why it's needed**:

- Defines the public methods that AIR applications call (initialize, setRumble, etc.)
- Manages the ExtensionContext for communicating with native code
- Provides type safety and error handling for AS3 developers
- Acts as the bridge between high-level AS3 code and low-level native functions

## `src-native/` Directory

### `RumbleANE.h`

**Purpose**: C++ header file containing structure definitions, function declarations, and includes.

**Why it's needed**:

- Defines the DeviceRegistry and XInputDevice structures for tracking controllers
- Declares all FRE (Flash Runtime Extensions) functions that AS3 can call
- Includes necessary Windows and AIR headers
- Provides the interface contract between different parts of the native code

### `RumbleANE.cpp`

**Purpose**: Main C++ implementation file containing all the native functionality.

**Why it's needed**:

- Implements the core rumble logic using Windows XInput API
- Contains FRE function implementations that respond to AS3 calls
- Manages controller enumeration and state tracking
- Handles threading for duration-based vibration control

### `RumbleANE.vcxproj`

**Purpose**: Visual Studio project file that defines how to compile the C++ code.

**Why it's needed**:

- Tells MSBuild how to compile the source files
- Specifies include directories, library dependencies, and compiler settings
- Defines build configurations for Debug/Release and x86/x64 platforms
- Required by the build script to compile the native DLLs

### `Release/` and `x64/`

**Purpose**: Build output directories for compiled binaries.

**Why it's needed**:

- Contain intermediate object files and final DLLs from compilation
- Allow the build script to locate compiled binaries for packaging
- Provide separate directories for different architectures

## `swc_extract/` Directory

**Purpose**: Temporary directory for extracting SWC contents during the build process.

**Why it's needed**:

- Allows inspection and manipulation of compiled AS3 code
- Required by the packaging process to combine SWC contents with native libraries
- Provides a staging area for build artifacts

## `win-x86/` and `win-x86-64/` Directories

### `RumbleANE.dll` / `RumbleANE64.dll`

**Purpose**: The compiled native DLLs for 32-bit and 64-bit Windows.

**Why it's needed**:

- Contain the actual machine code that implements controller vibration
- Loaded by Adobe AIR at runtime when the extension is used
- Platform-specific versions ensure compatibility with different Windows architectures
- The core native implementation that provides the rumble functionality

### `library.swf`

**Purpose**: ActionScript bytecode extracted from the SWC for ANE packaging.

**Why it's needed**:

- Required by Adobe AIR's ANE format for the AS3 interface
- Contains the compiled Rumble.as class that AIR applications import
- Must be packaged with the native DLLs in the ANE

## Summary

The RumbleANE folder contains a complete development environment for building an Adobe Native Extension that provides controller rumble functionality. Each file and directory serves a specific purpose in the build pipeline, from source code compilation to final packaging. The modular structure allows for:

- **Cross-platform development**: Separate handling of AS3 and native code
- **Multi-architecture support**: Both x86 and x64 Windows builds
- **Professional distribution**: Proper signing and packaging for production use

This comprehensive structure ensures that developers can build, test, and distribute a fully functional controller vibration extension for Adobe AIR applications.
