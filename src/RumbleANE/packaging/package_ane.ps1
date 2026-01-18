# Packages the ANE using Adobe AIR adt.
param(
    [string]$AIRSDK = "c:\aflex_sdk",
    [string]$Cert = "ane-cert.p12",
    [string]$Password = "password"
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$aneRoot = Split-Path -Parent $root
$projRoot = Split-Path -Parent $aneRoot

# Build SWC from AS3 wrapper (requires compc)
$as3Dir = Join-Path $aneRoot 'src-as3'
$swcOut = Join-Path $root 'RumbleANE.swc'

$compc = Join-Path $AIRSDK 'bin\compc.exe'
& $compc -source-path $as3Dir -include-classes com.mcleodgaming.ane.rumble.Rumble -output $swcOut

# Package ANE
$adt = Join-Path $AIRSDK 'bin\adt.bat'
$extXml = Join-Path $root 'extension.xml'
$aneOut = Join-Path $root 'RumbleANE.ane'

& $adt -package -target ane $aneOut $extXml -swc $swcOut `
  -platform Windows-x86 -C (Join-Path $aneRoot 'win-x86') RumbleANE.dll `
  -platform Windows-x86-64 -C (Join-Path $aneRoot 'win-x86-64') RumbleANE64.dll `
  -storetype pkcs12 -keystore (Join-Path $root $Cert) -storepass $Password

Write-Host "Packaged ANE:" $aneOut
