# SaveData.as Rumble Integration

## Overview

This file handles persistence of rumble settings across game sessions.

## Required Import

```actionscript
import com.mcleodgaming.ssf2.input.Gamepad;
```

## Settings Loading

In the `loadSettings()` method, add this line to load and apply the rumble setting:

```actionscript
// Load rumble setting
Gamepad.setGlobalRumbleEnabled(SaveData.getRumbleEnabled());
```

## Getter Method

Add this method to retrieve the persisted rumble setting:

```actionscript
/**
 * Get rumble enabled setting (persisted)
 */
public static function getRumbleEnabled():Boolean
{
    // Default to true if not set
    if (m_localObject.game.options.rumbleEnabled === undefined)
    {
        return true;
    }
    return (m_localObject.game.options.rumbleEnabled as Boolean);
}
```

## Setter Method

Add this method to persist the rumble setting:

```actionscript
/**
 * Set rumble enabled setting (persisted)
 */
public static function setRumbleEnabled(value:Boolean):void
{
    m_localObject.game.options.rumbleEnabled = value;
    // Also sync to Gamepad static
    Gamepad.setGlobalRumbleEnabled(value);
}
```
