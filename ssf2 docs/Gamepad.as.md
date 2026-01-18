# Gamepad.as Rumble Integration

## Overview

This file contains the primary rumble implementation for SSF2. It handles dynamic XInput detection, ANE-based rumble commands, and all gameplay rumble events.

## Required Imports

```actionscript
import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.filesystem.File;
import flash.net.DatagramSocket;
import flash.events.DatagramSocketDataEvent;
import flash.utils.ByteArray;
import flash.utils.getTimer;
import com.mcleodgaming.ssf2.util.SaveData;
import com.masterwex.ane.rumble.Rumble;
import com.iam2bam.ane.nativejoystick.NativeJoystick;
```

## Static Variables to Add

```actionscript
// Feature flags
private static var USE_ANE_RUMBLE:Boolean = true;
private static var m_aneReady:Boolean = false;
private static var m_aneInitLogged:Boolean = false; // Avoid spamming failures if ANE is missing
private static var ENABLE_RUMBLE_DEBUG:Boolean = false;

// Rate limiting to prevent socket flooding (min ms between commands per controller)
private static var m_lastRumbleTime:Object = {};
private static const RUMBLE_MIN_INTERVAL:int = 16; // ~60fps max rate

// Global rumble setting (persisted via SaveData)
private static var m_globalRumbleEnabled:Boolean = true;

// Device correlation mapping: NativeJoystick index -> XInput index
private static var m_deviceMapping:Object = {}; // Maps nativeJoystickIndex -> xinputIndex
private static var m_deviceMappingDirty:Boolean = true; // True when mapping needs refresh
```

## Instance Variables to Add

```actionscript
protected var m_xinputIndex:int = -1; // Actual XInput device index for rumble
protected var m_xinputDetected:Boolean = false; // True once we've detected the real XInput index
protected var m_rumbleEnabled:Boolean = true;
```

## Constructor Modifications

Update the constructor to initialize rumble variables:

```actionscript
public function Gamepad(name:String, port:int, xinputIndex:int = -1):void
{
    // ... existing code ...
    this.m_xinputIndex = xinputIndex;
    this.m_xinputDetected = false;
    // ... rest of constructor ...
}
```

## Dynamic XInput Detection Method

Add this method to detect the real XInput index on first button press:

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

## Button Press Trigger

Modify `onDeviceInput()` to trigger detection on first button press:

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

## Rumble Methods

Add the main rumble functionality:

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

public function stopRumble():void
{
    this.setRumble(0, 0, 0);
}

public function supportsRumble():Boolean
{
    return m_aneReady;
}

public function getRumbleEnabled():Boolean
{
    return this.m_rumbleEnabled;
}

public function setRumbleEnabled(enabled:Boolean):void
{
    this.m_rumbleEnabled = enabled;
}
```

## Static Rumble Methods

Add all the static rumble methods for gameplay integration:

```actionscript
public static function setGlobalRumbleEnabled(enabled:Boolean):void
{
    m_globalRumbleEnabled = enabled;
}

public static function getGlobalRumbleEnabled():Boolean
{
    return m_globalRumbleEnabled;
}

public static function toggleGlobalRumble():Boolean
{
    m_globalRumbleEnabled = !m_globalRumbleEnabled;
    return m_globalRumbleEnabled;
}

public static function rumbleForPlayer(playerID:int, left:Number, right:Number, duration:int):void
{
    if (!m_globalRumbleEnabled) return;

    try
    {
        // playerID is 1-based, Controllers array is 0-based
        var index:int = playerID - 1;
        if (SaveData.Controllers && index >= 0 && index < SaveData.Controllers.length && SaveData.Controllers[index])
        {
            var gamepad:Gamepad = SaveData.Controllers[index].GamepadInstance;
            if (gamepad != null)
            {
                gamepad.setRumble(left, right, duration);
            }
        }
    }
    catch (e:Error)
    {
        // Silently ignore errors - rumble is non-critical
    }
}

// Combat feedback
public static function rumbleOnHit(playerID:int, damage:Number, knockback:Number):void
{
    // Scale intensity based on damage (3-20 damage range mapped to 0.2-0.8)
    var intensity:Number = Math.min(0.8, Math.max(0.2, damage / 25));
    // Duration scales with knockback (50-150ms)
    var duration:int = Math.min(150, Math.max(50, int(knockback * 2)));
    rumbleForPlayer(playerID, intensity * 0.8, intensity, duration);
}

public static function rumbleOnDamage(playerID:int, damage:Number, knockback:Number):void
{
    // Heavier rumble for taking hits - left motor dominant
    var intensity:Number = Math.min(1.0, Math.max(0.3, damage / 20));
    // Stronger knockback = longer rumble (80-200ms)
    var duration:int = Math.min(200, Math.max(80, int(knockback * 5)));
    rumbleForPlayer(playerID, intensity, intensity * 0.6, duration);
}

public static function rumbleOnKO(playerID:int):void
{
    rumbleForPlayer(playerID, 1.0, 0.8, 200);
}

// Shield interactions
public static function rumbleOnShieldHit(playerID:int):void
{
    rumbleForPlayer(playerID, 0.1, 0.2, 40);
}

public static function rumbleOnShieldBreak(playerID:int):void
{
    rumbleForPlayer(playerID, 1.0, 1.0, 300);
}

// Movement & physics
public static function rumbleOnLand(playerID:int, fallSpeed:Number):void
{
    // Only rumble for notable landings (fall speed > 5)
    if (fallSpeed < 5) return;
    // Scale intensity based on fall speed (5-25 mapped to 0.1-0.4)
    var intensity:Number = Math.min(0.4, Math.max(0.1, fallSpeed / 60));
    // Duration 30-80ms
    var duration:int = Math.min(80, Math.max(30, int(fallSpeed * 2)));
    rumbleForPlayer(playerID, intensity, intensity * 0.5, duration);
}

public static function rumbleOnTech(playerID:int):void
{
    rumbleForPlayer(playerID, 0.2, 0.4, 50);
}

public static function rumbleOnLedgeGrab(playerID:int):void
{
    rumbleForPlayer(playerID, 0.15, 0.3, 40);
}

// Grab system
public static function rumbleOnGrab(playerID:int):void
{
    rumbleForPlayer(playerID, 0.3, 0.5, 60);
}

public static function rumbleOnGrabbed(playerID:int):void
{
    rumbleForPlayer(playerID, 0.4, 0.2, 80);
}

// Special events
public static function rumbleOnScreenKO(playerID:int):void
{
    rumbleForPlayer(playerID, 1.0, 1.0, 250);
}

public static function rumbleOnStarKO(playerID:int):void
{
    rumbleForPlayer(playerID, 0.6, 0.4, 150);
}

public static function rumbleOnFinalSmash(playerID:int):void
{
    rumbleForPlayer(playerID, 0.8, 1.0, 300);
}

public static function rumbleOnMeteor(playerID:int):void
{
    rumbleForPlayer(playerID, 0.7, 0.9, 120);
}
```

## ANE Helper Methods

Add the ANE communication methods:

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

## Helper Method

Add this helper method for button bit detection:

```actionscript
private function getXInputButtonBit(buttonId:String):uint
{
    switch (buttonId)
    {
        case "BUTTON_0": return 0x1000; // A
        case "BUTTON_1": return 0x2000; // B
        case "BUTTON_2": return 0x4000; // X
        case "BUTTON_3": return 0x8000; // Y
        case "BUTTON_4": return 0x0100; // LB
        case "BUTTON_5": return 0x0200; // RB
        case "BUTTON_6": return 0x0020; // BACK
        case "BUTTON_7": return 0x0010; // START
        case "BUTTON_8": return 0x0040; // LS
        case "BUTTON_9": return 0x0080; // RS
        default: return 0;
    }
}
```

## Device Mapping Method

Add this method for device mapping (if needed):

```actionscript
public static function refreshDeviceMapping():void
{
    // Maps NativeJoystick indices to XInput indices
    m_deviceMapping = {};
    var nativeJoysticks:Array = GamepadManager.getNativeJoysticks();

    for each (var nativeJoy:NativeJoystick in nativeJoysticks)
    {
        m_deviceMapping[nativeJoy.index] = nativeJoy.index; // Assume 1:1 mapping
    }

    m_deviceMappingDirty = false;
}

public static function getMappedXInputIndex(nativeIndex:int):int
{
    if (m_deviceMappingDirty) refreshDeviceMapping();
    return m_deviceMapping[nativeIndex] || nativeIndex;
}

public static function listControllers():void
{
    if (!ensureAneInitialized()) return;
    var controllers:* = Rumble.identifyActiveControllers();
    trace("[RUMBLE DEBUG] Active XInput controllers:", controllers);
}

public static function testRumble(port:int = 0):void
{
    if (!ensureAneInitialized()) return;
    trace("[RUMBLE DEBUG] Testing rumble on port " + port);
    sendRumbleCommand(port, 0.5, 0.5, 1000);
}
```
