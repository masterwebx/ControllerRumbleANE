# Rumble ANE Integration in SSF2 Engine

## Overview

The Rumble Adobe Native Extension (ANE) provides controller vibration support for Super Smash Flash 2 (SSF2), enabling haptic feedback during gameplay. This document details the complete Rumble ANE architecture, current implementation with dynamic XInput mapping, and all integration details.

## Current Implementation Status

**Last verified working:** January 2026 - Dynamic XInput detection with ANE, debug logging, and full rumble support

### Key Features Implemented

- ✅ **Dynamic XInput Detection**: Runtime mapping of controllers on first button press
- ✅ **ANE-Based Rumble**: Direct native XInput calls via Adobe Native Extension
- ✅ **Debug Logging**: Conditional trace output with `ENABLE_RUMBLE_DEBUG` flag
- ✅ **Multi-Controller Support**: Up to 4 controllers with automatic mapping
- ✅ **Rate Limiting**: 60fps max rumble frequency to prevent flooding
- ✅ **Error Handling**: Graceful fallbacks when ANE fails

### Architecture Overview

The implementation uses a hybrid approach:

1. **Detection**: ANE polls XInput controllers and maps them dynamically
2. **Rumble**: ANE sends vibration commands directly to XInput API
3. **Debugging**: Conditional logging for troubleshooting

```
Game Button Press → detectXInputIndex() → ANE.identifyActiveControllers()
       ↓
XInput Polling → Map controller → setRumble() → ANE.setRumble()
       ↓
Hardware Vibration
```

## Architecture

### Components

1. **Rumble ANE (Native Extension)**
   - ActionScript 3 API (`Rumble.as`)
   - Native C++ implementation (`RumbleANE.cpp`, `RumbleANE.h`)
   - Compiled into `RumbleANE.ane` for AIR packaging

2. **SSF2 Engine Integration**
   - `Gamepad.as` - Primary integration point for rumble functionality
   - `GamepadManager.as` - Controller enumeration and management
   - SaveData persistence for user rumble preferences

3. **Controller Support**
   - **Xbox Controllers**: Direct XInput API support via ANE

### Data Flow

```
Gameplay Event → Gamepad.setRumble() → Rumble.setRumble() → Native XInputSetState()
     ↓
SSF2 Engine                    ANE AS3 API              ANE Native DLL
```

## ActionScript 3 API

The `Rumble.as` class provides the AS3 interface to the native extension:

### Core Functions

- `initialize()`: Initializes the extension and enumerates controllers
- `setRumble(xinputIndex, left, right, durationMs)`: Sets vibration for Xbox controllers
- `identifyActiveControllers()`: Returns JSON with active controller information
- `stopAll()`: Stops vibration on all controllers
- `shutdown()`: Cleans up resources

### Usage Pattern

```actionscript
// Initialize once at startup
if (Rumble.initialize()) {
    // Set rumble: controller 0, 50% left motor, 75% right motor, 500ms duration
    Rumble.setRumble(0, 0.5, 0.75, 500);

    // Stop all vibration
    Rumble.stopAll();

    // Cleanup on exit
    Rumble.shutdown();
}
```

## Native C++ Implementation

### Key Structures

```cpp
struct XInputDevice {
    int index;          // XInput controller index (0-3)
    uint16_t vid;       // Vendor ID
    uint16_t pid;       // Product ID
    std::string devicePath; // HID device path
};

struct DeviceRegistry {
    std::vector<XInputDevice> xinput;
    std::mutex mtx;     // Thread safety
};
```

### FRE Functions

The extension exposes these Flash Runtime Extensions (FRE) functions:

- `fr_initialize`: Enumerates connected controllers
- `fr_setRumble`: Sets XInput vibration with optional duration
- `fr_identifyActiveControllers`: Returns JSON controller info
- `fr_stopAll`: Stops all controller vibration
- `fr_shutdown`: Cleanup and stop all vibration

### XInput Integration

```cpp
// Set vibration motors
XINPUT_VIBRATION vib;
vib.wLeftMotorSpeed = (WORD)(left * 65535.0);    // 0-65535 range
vib.wRightMotorSpeed = (WORD)(right * 65535.0);
XInputSetState(controllerIndex, &vib);

// Duration-based stop (detached thread)
if (durationMs > 0) {
    std::thread([controllerIndex, durationMs] {
        Sleep(durationMs);
        XINPUT_VIBRATION zero = {0, 0};
        XInputSetState(controllerIndex, &zero);
    }).detach();
}
```

## SSF2 Engine Integration

### Gamepad.as Integration

The `Gamepad` class serves as the primary integration point with dynamic XInput detection:

#### Static Configuration

```actionscript
// Feature flags
private static var USE_ANE_RUMBLE:Boolean = true;
private static var m_aneReady:Boolean = false;
private static var m_aneInitLogged:Boolean = false;
private static var ENABLE_RUMBLE_DEBUG:Boolean = false; // NEW: Debug logging flag

// Rate limiting to prevent socket flooding (min ms between commands per controller)
private static var m_lastRumbleTime:Object = {};
private static const RUMBLE_MIN_INTERVAL:int = 16; // ~60fps max rate

// Global rumble setting (persisted via SaveData)
private static var m_globalRumbleEnabled:Boolean = true;

// Device correlation mapping: NativeJoystick index -> XInput index
private static var m_deviceMapping:Object = {}; // Maps nativeJoystickIndex -> xinputIndex
private static var m_deviceMappingDirty:Boolean = true; // True when mapping needs refresh
```

#### Dynamic XInput Detection

```actionscript
/**
 * Detect the real XInput index for this gamepad on first button press
 */
private function detectXInputIndex(buttonId:String):void
{
    var expectedBit:uint = this.getXInputButtonBit(buttonId);
    if (expectedBit == 0) return; // Unknown button

    var activeControllers:* = Rumble.identifyActiveControllers();
    if (!activeControllers) return;

    if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG] Detecting XInput index for button '" + buttonId + "' (bit 0x" + expectedBit.toString(16) + ")");

    for each (var index:int in activeControllers)
    {
        var state:Object = Rumble.getControllerState(index);
        if (state && state.buttons)
        {
            var buttons:uint = uint(state.buttons);
            if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG]   XInput[" + index + "] buttons: 0x" + buttons.toString(16));
            if ((buttons & expectedBit) != 0)
            {
                this.m_xinputIndex = index;
                this.m_xinputDetected = true;
                if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG]   Detected match! Mapping to XInput[" + index + "]");
                break;
            }
        }
    }

    if (this.m_xinputIndex == -1)
    {
        if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG]   No match found, keeping default mapping");
    }
}
```

#### Button Press Trigger

```actionscript
// In onDeviceInput() - trigger detection on first button press
if (((state.value) && (!(state.prevValue))))
{
    // Button just pressed - detect real XInput index if not yet detected
    if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG] Button pressed: '" + state.id + "', m_xinputDetected=" + this.m_xinputDetected);
    if (!this.m_xinputDetected)
    {
        this.detectXInputIndex(state.id);
    }
    // ... rest of button handling
}
```

#### Rumble Commands

```actionscript
public function setRumble(leftMotor:Number = 0.0, rightMotor:Number = 0.0, duration:int = 0):void
{
    // Check global and per-gamepad settings
    if (!m_globalRumbleEnabled || !this.m_rumbleEnabled) return;

    // Value clamping and validation
    leftMotor = Math.max(0, Math.min(1, leftMotor));
    rightMotor = Math.max(0, Math.min(1, rightMotor));
    if (leftMotor <= 0 && rightMotor <= 0) return;

    // Use detected XInput index, fallback to port
    var rumbleIndex:int = (this.m_xinputIndex >= 0) ? this.m_xinputIndex : this.m_port;

    // DEBUG: Log exactly what we're sending
    if (ENABLE_RUMBLE_DEBUG) {
        trace("[RUMBLE DEBUG] Gamepad.setRumble() called:");
        trace("  -> Gamepad Name: " + this.m_name);
        trace("  -> m_port (display): " + this.m_port);
        trace("  -> m_xinputIndex: " + this.m_xinputIndex);
        trace("  -> FINAL rumbleIndex being sent: " + rumbleIndex);
        trace("  -> Left: " + leftMotor + ", Right: " + rightMotor + ", Duration: " + duration);
    }

    // Route to Xbox XInput via ANE
    if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE] Xbox XInput: routing to ANE (port=" + rumbleIndex + ")");
    sendRumbleCommand(rumbleIndex, leftMotor, rightMotor, duration);
}
```

#### ANE Command Sending

```actionscript
private static function sendRumbleCommand(port:int, leftMotor:Number, rightMotor:Number, duration:int):void
{
    // Rate limiting
    var now:int = getTimer();
    var lastTime:int = m_lastRumbleTime[port] || 0;
    if (now - lastTime < RUMBLE_MIN_INTERVAL && leftMotor > 0) return;
    m_lastRumbleTime[port] = now;

    // Ensure ANE is initialized
    if (!ensureAneInitialized()) return;

    // Send via ANE
    try
    {
        if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG] Calling Rumble.setRumble with port=" + port + ", left=" + leftMotor + ", right=" + rightMotor + ", duration=" + duration);
        var result:Boolean = Rumble.setRumble(port, leftMotor, rightMotor, duration);
        if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG] Rumble.setRumble returned: " + result);
        if (!result)
        {
            if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG] ANE setRumble failed");
        }
    }
    catch (e:Error)
    {
        if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG] Rumble.setRumble threw error: " + e.message);
    }
}
```

#### ANE Initialization

```actionscript
private static function ensureAneInitialized():Boolean
{
    if (!m_aneReady)
    {
        try
        {
            m_aneReady = Rumble.initialize();
            if (m_aneReady)
            {
                var info:Object = Rumble.identifyActiveControllers();
                if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE ANE] Initialized successfully. Active controllers:", info);
                m_aneInitLogged = false;
            }
            else
            {
                if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE ANE] Rumble.initialize() returned false");
            }
        }
        catch (e:Error)
        {
            m_aneReady = false;
            if (!m_aneInitLogged)
            {
                if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE ANE] Initialization error (ANE likely not packaged or failed to load): " + e.message);
                m_aneInitLogged = true;
            }
        }
        if (!m_aneReady && !m_aneInitLogged)
        {
            if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE ANE] Rumble.initialize() returned false; ANE not ready so rumble will fall back.");
            m_aneInitLogged = true;
        }
    }
    return m_aneReady;
}
```

### Global Rumble Settings

```actionscript
public static function getGlobalRumbleEnabled():Boolean {
    return m_globalRumbleEnabled;
}

public static function setGlobalRumbleEnabled(enabled:Boolean):void {
    m_globalRumbleEnabled = enabled;
    SaveData.setValue("rumble_enabled", enabled);
}

public static function toggleGlobalRumble():Boolean {
    m_globalRumbleEnabled = !m_globalRumbleEnabled;
    SaveData.setValue("rumble_enabled", m_globalRumbleEnabled);
    return m_globalRumbleEnabled;
}
```

### Device Mapping

```actionscript
public static function refreshDeviceMapping():void {
    // Maps NativeJoystick indices to XInput indices
    m_deviceMapping = {};
    var nativeJoysticks:Array = GamepadManager.getNativeJoysticks();

    for each (var nativeJoy:NativeJoystick in nativeJoysticks) {
        m_deviceMapping[nativeJoy.index] = nativeJoy.index; // Assume 1:1 mapping
    }

    m_deviceMappingDirty = false;
}
```

## Gameplay Integration

### Rumble Events

The game triggers controller rumble for various gameplay events through static methods in `Gamepad.as`:

#### Combat Feedback

```actionscript
// Attacker feels satisfying rumble when landing hits
Gamepad.rumbleOnHit(playerID, damage, knockback);

// Defender feels impact when taking damage
Gamepad.rumbleOnDamage(playerID, damage, knockback);

// Strong feedback for KO/death
Gamepad.rumbleOnKO(playerID);
```

#### Shield Interactions

```actionscript
// Light feedback when shield is hit
Gamepad.rumbleOnShieldHit(playerID);

// Strong rumble when shield breaks
Gamepad.rumbleOnShieldBreak(playerID);
```

#### Movement & Physics

```actionscript
// Landing feedback scales with fall speed
Gamepad.rumbleOnLand(playerID, fallSpeed);

// Ledge grab feedback
Gamepad.rumbleOnLedgeGrab(playerID);

// Teching (bounce off ground/wall)
Gamepad.rumbleOnTech(playerID);
```

#### Grab System

```actionscript
// Successful grab (attacker)
Gamepad.rumbleOnGrab(playerID);

// Being grabbed (defender)
Gamepad.rumbleOnGrabbed(playerID);
```

#### Special Events

```actionscript
// Screen KO (hitting blast zones)
Gamepad.rumbleOnScreenKO(playerID);
```

### Menu Integration

```actionscript
// Title screen button press feedback
gamepad.setRumble(0.4, 0.4, 80);

// Controls menu toggle feedback (TAUNT button)
gamepad.setRumble(0.5, 0.5, 80);
```

### Settings Integration

Rumble settings are persisted through `SaveData`:

```actionscript
// Global toggle (affects all players)
Gamepad.setGlobalRumbleEnabled(enabled);
Gamepad.toggleGlobalRumble(); // Returns new state

// Per-controller toggle (rarely used)
gamepad.setRumbleEnabled(enabled);
```

### Intensity Scaling

Rumble intensity and duration scale with gameplay values:

- **Damage**: 3-20 damage → 0.2-0.8 intensity
- **Knockback**: Higher knockback → longer duration (50-150ms)
- **Fall Speed**: Faster falls → stronger landing rumble (0.1-0.4 intensity)
- **Shield Break**: Maximum intensity (1.0) for 300ms
- **KO Events**: Strong sustained rumble (200-250ms)

### Player Targeting

All rumble functions target specific players (1-4) and automatically route to the correct controller:

```actionscript
public static function rumbleForPlayer(playerID:int, left:Number, right:Number, duration:int):void
{
    // playerID is 1-based, Controllers array is 0-based
    var index:int = playerID - 1;
    if (SaveData.Controllers && index >= 0 && index < SaveData.Controllers.length)
    {
        var gamepad:Gamepad = SaveData.Controllers[index].GamepadInstance;
        if (gamepad != null)
        {
            gamepad.setRumble(left, right, duration);
        }
    }
}
```

## Controller Support Details

### Xbox Controllers (XInput)

- **API**: Windows XInput 1.4
- **Controllers**: Xbox 360, Xbox One, Xbox Series X|S
- **Motors**: Two independent vibration motors (left/right)
- **Range**: 0-65535 (16-bit)
- **Duration**: Handled by detached threads in native code

## Build Process

### ANE Packaging

1. **Compile Native DLLs**

   ```powershell
   # build.ps1 compiles for x86 and x64
   MSBuild RumbleANE.vcxproj /p:Configuration=Release /p:Platform=x86
   MSBuild RumbleANE.vcxproj /p:Configuration=Release /p:Platform=x64
   ```

2. **Compile AS3 Library**

   ```batch
   compc -source-path src-as3 -include-classes com.masterwex.ane.rumble.Rumble -output Rumble.swc
   ```

3. **Package ANE**
   ```batch
   adt -package -target ane RumbleANE.ane extension.xml -swc Rumble.swc -platform Windows-x86 -C native-libs Windows-x86 . -platform Windows-x86-64 -C native-libs Windows-x86-64 .
   ```

### SSF2 Integration

The ANE is included in the AIR application descriptor and packaged with the game.

## Error Handling

### ANE Initialization Failures

```actionscript
try {
    m_aneReady = Rumble.initialize();
} catch (e:Error) {
    m_aneReady = false;
    if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE ANE] Initialization error: " + e.message);
}
```

### Runtime Errors

```actionscript
try {
    var result:Boolean = Rumble.setRumble(port, left, right, duration);
} catch (e:Error) {
    if (ENABLE_RUMBLE_DEBUG) trace("[RUMBLE DEBUG] ANE error: " + e.message);
    // Fallback to UDP if available
}
```

## Performance Considerations

### Rate Limiting

- Minimum 16ms between commands (~60fps max)
- Prevents controller flooding
- Per-controller timing tracking

### Threading

- Duration-based stops use detached threads
- No blocking of main game thread
- Native code handles timing

## Future Enhancements

### Enhanced Features

- More granular motor control
- Pattern-based vibration sequences
- Audio-driven haptic feedback

## Troubleshooting

### Common Issues

1. **ANE not loading**: Check AIR application descriptor includes the extension
2. **No vibration**: Verify XInput-compatible controllers connected
3. **Initialization errors**: Check native DLLs are packaged correctly

### Debug Output

Enable `ENABLE_RUMBLE_DEBUG = true` in `Gamepad.as` for detailed rumble debugging:

```
[RUMBLE DEBUG] Detecting XInput index for button 'A' (bit 0x1000)
[RUMBLE DEBUG]   XInput[0] buttons: 0x1000
[RUMBLE DEBUG]   Detected match! Mapping to XInput[0]
[RUMBLE DEBUG] Calling Rumble.setRumble with port=0, left=0.5, right=0.3, duration=200
[RUMBLE DEBUG] Rumble.setRumble returned: true
```

## Dependencies

- **Adobe AIR SDK**: For AS3 compilation and ANE packaging
- **Microsoft Visual Studio**: C++ compilation
- **Windows XInput**: Built-in Windows API

## File Structure

```
ane/rumble/
├── README.md                    # Project documentation
├── build.ps1                    # Build script
├── src-as3/
│   └── com/masterwex/ane/rumble/Rumble.as  # AS3 API
├── src-native/
│   ├── RumbleANE.h              # C++ headers
│   ├── RumbleANE.cpp            # C++ implementation
│   └── RumbleANE.vcxproj        # Visual Studio project
├── packaging/                   # ANE packaging files
└── win-x86/, win-x86-64/        # Compiled DLLs
```

This implementation provides robust controller vibration support for SSF2, with direct native performance for Xbox controllers.</content>
<parameter name="filePath">c:\Users\masterwebx\Documents\GitHub\ssf2-idk-140x-original\src\Super Smash Flash 2 Beta v1.4.0.1\RUMBLE_ANE_INTEGRATION.md
