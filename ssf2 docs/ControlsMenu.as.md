# ControlsMenu.as Rumble Integration

## Overview

This file handles the rumble toggle functionality in the controls menu using the TAUNT button. It includes event listener setup for gamepad button detection and proper listener management when switching player tabs.

## Required Imports

```actionscript
import com.mcleodgaming.ssf2.input.Gamepad;
import com.mcleodgaming.ssf2.util.SaveData;
import com.mcleodgaming.ssf2.managers.MultiplayerManager;
import com.mcleodgaming.ssf2.events.GamepadEvent;
```

## Event Listener Setup

Add `GamepadEvent.BUTTON_DOWN` listeners in the following methods to enable rumble toggle via TAUNT button:

### makeEvents() Additions

In `makeEvents()`, after the existing gamepad listener setup:

```actionscript
if (SaveData.Controllers[(this.playNum - 1)].GamepadInstance)
{
    SaveData.Controllers[(this.playNum - 1)].GamepadInstance.addEventListener(GamepadEvent.AXIS_CHANGED, this.onAxisChanged);
    SaveData.Controllers[(this.playNum - 1)].GamepadInstance.addEventListener(GamepadEvent.BUTTON_DOWN, this.onGamepadButtonDown);
    m_subMenu.controlStickConfig.visible = true;
    m_subMenu.cStickConfig.visible = true;
}
```

### killEvents() Additions

In `killEvents()`, add removal of the BUTTON_DOWN listener:

```actionscript
if (SaveData.Controllers[(this.playNum - 1)].GamepadInstance)
{
    SaveData.Controllers[(this.playNum - 1)].GamepadInstance.removeEventListener(GamepadEvent.AXIS_CHANGED, this.onAxisChanged);
    SaveData.Controllers[(this.playNum - 1)].GamepadInstance.removeEventListener(GamepadEvent.BUTTON_DOWN, this.onGamepadButtonDown);
}
```

### inputTypeChanged() Additions

In `inputTypeChanged()`, add listener management when switching gamepads:

```actionscript
if (gamepad)
{
    SaveData.PortInputs[this.playNum] = ((gamepad.Name + " ") + gamepad.Port);
    SaveData.Gamepads[gamepad.Name] = ((SaveData.Gamepads[gamepad.Name]) || ({
                        "names": {},
                        "ports": {}
                    }));
    gamepad.addEventListener(GamepadEvent.AXIS_CHANGED, this.onAxisChanged);
    gamepad.addEventListener(GamepadEvent.BUTTON_DOWN, this.onGamepadButtonDown);
    // ... rest of gamepad setup
}
```

Also, add logic to prevent duplicate gamepad assignment:

```actionscript
// Clear this gamepad from any other player slots to prevent duplicate assignment
if (gamepad != null)
{
    for (var i:int = 0; i < SaveData.Controllers.length; i++)
    {
        if (i != (this.playNum - 1) && SaveData.Controllers[i].GamepadInstance === gamepad)
        {
            SaveData.Controllers[i].GamepadInstance = null;
            SaveData.PortInputs[(i + 1)] = null;
        }
    }
}
```

### Player Tab Switching

Modify player control click functions (`p1Controls_CLICK`, `p2Controls_CLICK`, etc.) to call `updateGamepadListeners`:

```actionscript
private function p1Controls_CLICK(e:MouseEvent):void
{
    SoundQueue.instance.playSoundEffect("menu_select");
    var oldPlayNum:int = this.playNum;
    this.playNum = 1;
    this.updateGamepadListeners(oldPlayNum, this.playNum);
    // ... rest of function
}
```

Add the `updateGamepadListeners` function:

```actionscript
/**
 * Update gamepad listeners when switching player tabs
 * This ensures TAUNT button toggle works for each player's controller
 * @param oldPlayNum Previous player tab (1-4)
 * @param newPlayNum New player tab (1-4)
 */
private function updateGamepadListeners(oldPlayNum:int, newPlayNum:int):void
{
    // Remove listeners from old player's gamepad
    if (oldPlayNum >= 1 && oldPlayNum <= 4)
    {
        var oldGamepad:Gamepad = SaveData.Controllers[(oldPlayNum - 1)].GamepadInstance;
        if (oldGamepad)
        {
            oldGamepad.removeEventListener(GamepadEvent.AXIS_CHANGED, this.onAxisChanged);
            oldGamepad.removeEventListener(GamepadEvent.BUTTON_DOWN, this.onGamepadButtonDown);
        }
    }

    // Add listeners to new player's gamepad
    if (newPlayNum >= 1 && newPlayNum <= 4)
    {
        var newGamepad:Gamepad = SaveData.Controllers[(newPlayNum - 1)].GamepadInstance;
        if (newGamepad)
        {
            newGamepad.addEventListener(GamepadEvent.AXIS_CHANGED, this.onAxisChanged);
            newGamepad.addEventListener(GamepadEvent.BUTTON_DOWN, this.onGamepadButtonDown);
            m_subMenu.controlStickConfig.visible = true;
            m_subMenu.cStickConfig.visible = true;
        }
        else
        {
            m_subMenu.controlStickConfig.visible = false;
            m_subMenu.cStickConfig.visible = false;
        }
    }
}
```

## Gamepad Button Handler

Add this method to handle TAUNT button presses for rumble toggling:

```actionscript
/**
 * Handle gamepad button press in controls menu - TAUNT toggles rumble
 */
private function onGamepadButtonDown(e:GamepadEvent):void
{
    var state:Object = e.controlState;

    if (state && state.inputs && state.inputs.indexOf("TAUNT") >= 0)
    {
        // Toggle global rumble setting
        var enabled:Boolean = Gamepad.toggleGlobalRumble();

        // Save to persistent storage
        SaveData.setRumbleEnabled(enabled);
        SaveData.saveGame();

        // Show notification
        MultiplayerManager.makeNotifier();
        if (enabled)
        {
            MultiplayerManager.notify("Controller Rumble: ON");
            // Give feedback rumble
            if (e.gamepad)
            {
                trace("[RUMBLE DEBUG] TAUNT pressed - About to rumble gamepad:");
                trace("  -> e.gamepad.Name: " + e.gamepad.Name);
                trace("  -> e.gamepad.Port: " + e.gamepad.Port);
                trace("  -> e.gamepad.XInputIndex: " + e.gamepad.XInputIndex);
                trace("  -> Current player tab: " + this.playNum);
                e.gamepad.setRumble(0.5, 0.5, 80);
            }
        }
        else
        {
            MultiplayerManager.notify("Controller Rumble: OFF");
        }

        SoundQueue.instance.playSoundEffect("menu_movecursor");
    }
}
```

## Additional Notes

- Update `shortenInputID()` signature to `shortenInputID(id:String, inverse:Boolean = false)` for consistency.
- Ensure all event listeners are properly added/removed to prevent memory leaks and ensure functionality across player tabs.
