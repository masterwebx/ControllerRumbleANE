# TitleMenu.as Rumble Integration

## Overview

This file provides rumble feedback when pressing the Play button on the title screen, with updated version display.

## Required Imports

```actionscript
import com.mcleodgaming.ssf2.input.Gamepad;
import com.mcleodgaming.ssf2.util.SaveData;
```

## Play Button Handler

Modify the `play_btn_CLICK` method to add rumble feedback:

```actionscript
private function play_btn_CLICK(e:MouseEvent):void
{
    if ((!(this.m_started)))
    {
        this.m_started = true;
        SoundQueue.instance.playSoundEffect("menu_selectstage");
        Main.Root.stage.addEventListener(Event.ENTER_FRAME, this.play_btn_ENTER_FRAME);
        m_subMenu.starter.play();

        // Rumble all connected controllers if rumble is enabled (indicates rumble is on)
        if (Gamepad.getGlobalRumbleEnabled())
        {
            for (var i:int = 0; i < SaveData.Controllers.length; i++)
            {
                var gamepad:Gamepad = SaveData.Controllers[i].GamepadInstance;
                if (gamepad != null)
                {
                    gamepad.setRumble(0.4, 0.4, 80);
                }
            }
        }
    };
}
```
