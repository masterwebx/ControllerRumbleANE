# Character.as Rumble Integration

## Overview

This file contains all gameplay rumble triggers. Rumble is called throughout various character actions, damage, special events, attacks, and items.

## Required Import

```actionscript
import com.mcleodgaming.ssf2.input.Gamepad;
```

## Grab System Rumble

### Successful Grab (Attacker)

In the grab logic, add rumble for the character performing the grab:

```actionscript
// Rumble feedback for grabber
if (character.m_human && character.ID > 0)
{
    Gamepad.rumbleOnGrab(character.ID);
}
```

### Being Grabbed (Defender)

In the grab handling code, add rumble for the character being grabbed:

```actionscript
// Rumble feedback for grabbed character
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnGrabbed(this.ID);
}
```

## Shield System Rumble

### Shield Break

In the shield break logic, add strong rumble:

```actionscript
// Rumble feedback for shield break
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnShieldBreak(this.ID);
}
```

### Shield Hit

In the shield damage logic, add light rumble:

```actionscript
// Rumble feedback for shield hit
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnShieldHit(this.ID);
}
```

## Movement & Physics Rumble

### Ledge Grab

In the ledge grab logic, add feedback:

```actionscript
// Rumble feedback for ledge grab
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnLedgeGrab(this.ID);
}
```

### Teching (Ground/Wall Bounce)

In the teching logic, add feedback:

```actionscript
// Rumble feedback for teching
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnTech(this.ID);
}
```

### Landing

In the ground collision logic, add landing feedback:

```actionscript
// Rumble feedback for landing
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnLand(this.ID, Math.abs(m_ySpeed + m_yKnockback));
}
```

## Combat Rumble

### Taking Damage

In the damage handling logic, add damage feedback:

```actionscript
// Rumble feedback for taking damage
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnDamage(this.ID, tempDamage, tempVelocity);
}
```

### Dealing Hit (Attacker)

In the hit confirmation logic, add attack feedback:

```actionscript
// Rumble feedback for successful hit
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnHit(this.ID, hitDamage, hitKnockback);
}
```

### Meteor Smash

In the meteor smash logic, add special feedback:

```actionscript
// Rumble feedback for meteor smash
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnMeteor(this.ID);
}
```

## Special Events Rumble

### Final Smash

In the final smash activation logic, add strong feedback:

```actionscript
// Rumble feedback for final smash
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnFinalSmash(this.ID);
}
```

### KO Events

In the death/KO logic, add strong feedback:

```actionscript
// Rumble feedback for KO
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnKO(this.ID);
}
```

### Screen KO

In the screen boundary KO logic, add maximum feedback:

```actionscript
// Rumble feedback for screen KO
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnScreenKO(this.ID);
}
```

### Star KO

In the star KO logic, add maximum feedback:

```actionscript
// Rumble feedback for star KO
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleOnStarKO(this.ID);
}
```

## Charge System Rumble

In the `incrementCharge()` function, add dynamic rumble for charge milestones:

```actionscript
// Rumble feedback for charge milestones
if (this.m_human && this.ID > 0)
{
    if (chargePercent >= 25 && chargePercent < 50)
    {
        Gamepad.rumbleForPlayer(m_player_id, 0.3, 0.4, 150);
    }
    else if (chargePercent >= 50 && chargePercent < 75)
    {
        Gamepad.rumbleForPlayer(m_player_id, 0.4, 0.4, 130);
    }
    else if (chargePercent >= 75 && chargePercent < 100)
    {
        Gamepad.rumbleForPlayer(m_player_id, 0.5, 0.4, 110);
    }
    else if (chargePercent >= 100)
    {
        Gamepad.rumbleForPlayer(m_player_id, 0.7, 0.5, 90);
    }
}
```

## Attack-Specific Rumble

### Special Attacks

In various special attack functions, add custom rumble patterns. For example:

```actionscript
// Light rumble for projectile attacks
Gamepad.rumbleForPlayer(m_player_id, 0.5, 0.45, 110);

// Medium rumble for charge attacks
Gamepad.rumbleForPlayer(m_player_id, 0.6, 0.5, 80);

// Strong rumble for smash attacks
Gamepad.rumbleForPlayer(m_player_id, 0.5, 0.45, 110);
```

### Aerial Attacks

In aerial attack functions:

```actionscript
// Rumble for aerial attacks
Gamepad.rumbleForPlayer(m_player_id, 0.4, 0.35, 120);
```

### Ground Attacks

In ground attack functions:

```actionscript
// Rumble for ground attacks
Gamepad.rumbleForPlayer(m_player_id, 0.35, 0.45, 140);
```

## Item Pickup Rumble

In item pickup logic, add feedback:

```actionscript
// Rumble feedback for item pickup
if (this.m_human && this.ID > 0)
{
    Gamepad.rumbleForPlayer(m_player_id, 0.4, 0.3, 120);
}
```

## Implementation Notes

- All rumble calls check `if (this.m_human && this.ID > 0)` to ensure only human players get rumble
- Rumble is called at the moment of action (grab, hit, landing, etc.)
- Intensity and duration vary based on the severity/importance of the action
- CPU characters do not receive rumble feedback
- Rumble calls are non-blocking and won't affect gameplay performance
