# Build script for RumbleANE
# Compiles C++ native DLLs (x86/x64) and packages the ANE
# Modified to work from any location within the ANE folder tree

param(
    [string]$AIRSDK = "c:\aflex_sdk",
    [string]$VSBuildToolsPath = "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools",
    [switch]$GenerateCert = $false,
    [string]$CertPassword = "password"
)

$ErrorActionPreference = "Stop"

# Find ANE root by searching for src-native folder
$currentPath = Get-Location
$aneRoot = $null

$searchPath = $currentPath
for ($i = 0; $i -lt 10; $i++) {
    if (Test-Path (Join-Path $searchPath "src-native")) {
        $aneRoot = $searchPath
        break
    }
    $parent = Split-Path -Parent $searchPath
    if ($parent -eq $searchPath) { break }
    $searchPath = $parent
}

if (-not $aneRoot) {
    Write-Host "[ERROR] Could not find ANE root. Please run this script from within the ane\rumble folder structure." -ForegroundColor Red
    exit 1
}

$nativeRoot = Join-Path $aneRoot "src-native"
$packagingRoot = Join-Path $aneRoot "packaging"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building RumbleANE (Windows x86/x64)" -ForegroundColor Cyan
Write-Host "ANE Root: $aneRoot" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan

# Find MSBuild
Write-Host "`n[1/5] Locating MSBuild..." -ForegroundColor Yellow
$msbuild = Join-Path $VSBuildToolsPath "MSBuild\Current\Bin\MSBuild.exe"

if (-not (Test-Path $msbuild)) {
    Write-Host "  2019 Build Tools not found at: $VSBuildToolsPath" -ForegroundColor Gray
    Write-Host "  Searching for other VS installations..." -ForegroundColor Gray
    
    $candidates = @(
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
    )
    
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $msbuild = $candidate
            Write-Host "  Found: $msbuild" -ForegroundColor Gray
            break
        }
    }
}

if (-not $msbuild -or -not (Test-Path $msbuild)) {
    Write-Host "[ERROR] MSBuild not found." -ForegroundColor Red
    Write-Host "  Expected path: $VSBuildToolsPath\MSBuild\Current\Bin\MSBuild.exe" -ForegroundColor Gray
    exit 1
}
Write-Host "[OK] MSBuild: $msbuild" -ForegroundColor Green

# Build Win32 (x86)
Write-Host "`n[2/5] Building Win32 (x86)..." -ForegroundColor Yellow
$vcxproj = Join-Path $nativeRoot "RumbleANE.vcxproj"
Write-Host "  Project: $vcxproj" -ForegroundColor Gray

if (-not (Test-Path $vcxproj)) {
    Write-Host "[ERROR] Project file not found: $vcxproj" -ForegroundColor Red
    exit 1
}

& $msbuild $vcxproj /p:Configuration=Release /p:Platform=Win32 /v:minimal
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Win32 build failed." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Win32 build succeeded" -ForegroundColor Green

# Copy x86 DLL to packaging folder
$builtDll32 = Join-Path $nativeRoot "Release\RumbleANE.dll"
if (Test-Path $builtDll32) {
    $dest32 = Join-Path $aneRoot "win-x86\RumbleANE.dll"
    New-Item -ItemType Directory -Force -Path (Split-Path $dest32) | Out-Null
    Copy-Item $builtDll32 $dest32 -Force
    Write-Host "  Copied x86 DLL -> $dest32" -ForegroundColor Gray
}

# Build x64
Write-Host "`n[3/5] Building x64..." -ForegroundColor Yellow
& $msbuild $vcxproj /p:Configuration=Release /p:Platform=x64 /v:minimal
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] x64 build failed." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] x64 build succeeded" -ForegroundColor Green

# Copy x64 DLL to packaging folder
$builtDll64 = Join-Path $nativeRoot "x64\Release\RumbleANE.dll"
if (Test-Path $builtDll64) {
    $dest64 = Join-Path $aneRoot "win-x86-64\RumbleANE64.dll"
    New-Item -ItemType Directory -Force -Path (Split-Path $dest64) | Out-Null
    Copy-Item $builtDll64 $dest64 -Force
    Write-Host "  Copied x64 DLL -> $dest64" -ForegroundColor Gray
}

# Verify DLLs
Write-Host "`n[4/5] Verifying DLLs..." -ForegroundColor Yellow
$dll32 = Join-Path $aneRoot "win-x86\RumbleANE.dll"
$dll64 = Join-Path $aneRoot "win-x86-64\RumbleANE64.dll"

if (-not (Test-Path $dll32)) {
    Write-Host "[ERROR] x86 DLL not found: $dll32" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $dll64)) {
    Write-Host "[ERROR] x64 DLL not found: $dll64" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] x86 DLL: $dll32" -ForegroundColor Green
Write-Host "[OK] x64 DLL: $dll64" -ForegroundColor Green

# Package ANE
Write-Host "`n[5/5] Packaging ANE..." -ForegroundColor Yellow
$swc = Join-Path $packagingRoot "RumbleANE.swc"
$extXml = Join-Path $packagingRoot "extension.xml"
$aneOut = Join-Path $packagingRoot "RumbleANE.ane"
$adt = Join-Path $AIRSDK "bin\adt.bat"

if (-not (Test-Path $adt)) {
    Write-Host "[ERROR] adt.bat not found: $adt" -ForegroundColor Red
    exit 1
}

# Rebuild SWC to ensure a compatible SWF version for ANE packaging
Write-Host "  Building SWC (library.swf <= v23)..." -ForegroundColor Cyan
$compc = Join-Path $AIRSDK "bin\compc.bat"
$as3Dir = Join-Path $aneRoot "src-as3"
& $compc -source-path $as3Dir -include-classes com.masterwex.ane.rumble.Rumble -external-library-path+="$AIRSDK\frameworks\libs\air\airglobal.swc" -swf-version=23 -output $swc
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] SWC build failed." -ForegroundColor Red
    exit 1
}

# Package the ANE (note: ANEs are not signed)
Write-Host "  Packaging RumbleANE.ane..." -ForegroundColor Cyan
$dir32 = Join-Path $aneRoot "win-x86"
$dir64 = Join-Path $aneRoot "win-x86-64"

# Extract library.swf from SWC for platform packaging
$swcExtract = Join-Path $packagingRoot "_swc"
if (Test-Path $swcExtract) { Remove-Item $swcExtract -Recurse -Force }
New-Item -ItemType Directory -Force -Path $swcExtract | Out-Null
$swcZip = Join-Path $packagingRoot "RumbleANE.zip"
Copy-Item $swc $swcZip -Force
Expand-Archive -Path $swcZip -DestinationPath $swcExtract -Force
Remove-Item $swcZip -Force

& $adt -package -target ane $aneOut $extXml -swc $swc `
    -platform Windows-x86 -C $swcExtract library.swf -C $dir32 RumbleANE.dll `
    -platform Windows-x86-64 -C $swcExtract library.swf -C $dir64 RumbleANE64.dll

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] ANE packaging failed." -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build successful!" -ForegroundColor Green
Write-Host "ANE output: $aneOut" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan