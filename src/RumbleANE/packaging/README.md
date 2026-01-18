# Rumble ANE Packaging

## Prerequisites

- Adobe AIR SDK (Flex SDK) at `c:\aflex_sdk`
- Visual Studio (MSVC) to build native DLLs
- Certificate for ANE packaging (`ane-cert.p12`)

## Build native DLLs

Build two binaries from `src-native`:

- `win-x86/RumbleANE.dll` (32-bit)
- `win-x86-64/RumbleANE64.dll` (64-bit)

Link `XInput.lib` (Windows SDK). For DualSense HID, use Win32 HID APIs (`SetupAPI.lib`) or integrate `hidapi`.

## Package ANE

Run:

```powershell
cd "src/Super Smash Flash 2 Beta v1.4.0.1/ane/rumble/packaging"
./package_ane.ps1 -AIRSDK c:\aflex_sdk -Cert ane-cert.p12 -Password password
```

This produces `RumbleANE.ane` with both architectures.

## Use in AIR project

- Add the ANE to your project ANE folder alongside `DiscordANE.ane` and `NativeJoystick.ane`.
- In `SSF2-app.xml`, add:
  - `<extensionID>com.masterwex.ane.rumble</extensionID>`
- In code, import `com.masterwex.ane.rumble.Rumble` and call `Rumble.initialize()`.
