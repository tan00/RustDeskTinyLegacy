param(
    [string]$PythonPath = "python",
    [string]$ToolRoot,
    [string]$OutputRoot,
    [string]$InstallerOutput,
    [string]$Proxy = "http://10.10.100.191:7890"
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$remoteDeskRoot = Split-Path -Parent $projectRoot
if ([string]::IsNullOrWhiteSpace($ToolRoot)) {
    $ToolRoot = Join-Path $remoteDeskRoot '.build-tools\rustdesk-tiny-legacy'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot 'dist\windows-x64-release'
}
if ([string]::IsNullOrWhiteSpace($InstallerOutput)) {
    $InstallerOutput = Join-Path $projectRoot 'dist\RustDeskTinyLegacy-install.exe'
}

$ToolRoot = [IO.Path]::GetFullPath($ToolRoot)
$OutputRoot = [IO.Path]::GetFullPath($OutputRoot)
$InstallerOutput = [IO.Path]::GetFullPath($InstallerOutput)
$distRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'dist')) + [IO.Path]::DirectorySeparatorChar
if (-not ($OutputRoot + [IO.Path]::DirectorySeparatorChar).StartsWith(
        $distRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputRoot must be inside $distRoot"
}

if ([string]::IsNullOrWhiteSpace($env:VCPKG_ROOT)) {
    throw 'VCPKG_ROOT is not set'
}
if ([string]::IsNullOrWhiteSpace($env:LIBCLANG_PATH)) {
    throw 'LIBCLANG_PATH is not set'
}
foreach ($required in @(
        (Join-Path $env:VCPKG_ROOT 'vcpkg.exe'),
        (Join-Path $env:LIBCLANG_PATH 'libclang.dll'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required build dependency is missing: $required"
    }
}

$flutterRoot = Join-Path $ToolRoot 'flutter-sdk-3.24.5'
$flutterExe = Join-Path $flutterRoot 'bin\flutter.bat'
$sourceFlutterRoot = Join-Path $remoteDeskRoot '.build-tools\flutter-sdk-3.24.5\flutter'
if (-not (Test-Path -LiteralPath $flutterExe -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceFlutterRoot 'bin\flutter.bat') -PathType Leaf)) {
        throw "Flutter 3.24.5 source SDK is missing: $sourceFlutterRoot"
    }
    New-Item -ItemType Directory -Path $ToolRoot -Force | Out-Null
    & robocopy.exe $sourceFlutterRoot $flutterRoot /E /MT:16 /R:2 /W:1 /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -ge 8) {
        throw "Flutter SDK copy failed with robocopy exit code $LASTEXITCODE"
    }
}

$engineDir = Join-Path $flutterRoot 'bin\cache\artifacts\engine\windows-x64-release'
$engineMarker = Join-Path $engineDir '.rustdesk-win7-engine'
if (-not (Test-Path -LiteralPath $engineMarker -PathType Leaf)) {
    & $flutterExe precache --windows
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Windows precache failed with exit code $LASTEXITCODE"
    }
    $engineArchive = Join-Path $ToolRoot 'windows-x64-release-win7.zip'
    if (-not (Test-Path -LiteralPath $engineArchive -PathType Leaf)) {
        $engineUri = 'https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip'
        try {
            Invoke-WebRequest -Uri $engineUri -OutFile $engineArchive
        }
        catch {
            Invoke-WebRequest -Uri $engineUri -OutFile $engineArchive -Proxy $Proxy
        }
    }
    $engineExtract = Join-Path $ToolRoot 'engine-extract'
    if (Test-Path -LiteralPath $engineExtract) {
        Remove-Item -LiteralPath $engineExtract -Recurse -Force
    }
    Expand-Archive -LiteralPath $engineArchive -DestinationPath $engineExtract
    Remove-Item -LiteralPath $engineDir -Recurse -Force
    New-Item -ItemType Directory -Path $engineDir -Force | Out-Null
    Copy-Item -Path (Join-Path $engineExtract '*') -Destination $engineDir -Recurse -Force
    New-Item -ItemType File -Path $engineMarker -Force | Out-Null
}

$previousPath = $env:PATH
$previousToolchain = $env:RUSTUP_TOOLCHAIN
$previousWrapper = $env:RUSTC_WRAPPER
$previousRustLog = $env:RUST_LOG
try {
    $env:PATH = (Join-Path $flutterRoot 'bin') + [IO.Path]::PathSeparator + $previousPath
    $env:RUSTUP_TOOLCHAIN = '1.75-x86_64-pc-windows-msvc'
    $env:RUSTC_WRAPPER = ''
    $env:RUST_LOG = 'info'

    $rustVersion = (& rustc --version)
    if ($LASTEXITCODE -ne 0 -or -not $rustVersion.StartsWith('rustc 1.75.')) {
        throw "Rust 1.75 is required; active compiler: $rustVersion"
    }
    & rustfmt --version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'rustfmt for Rust 1.75 is required; run: rustup component add rustfmt --toolchain 1.75-x86_64-pc-windows-msvc'
    }
    $flutterVersionOutput = & $flutterExe --version
    $flutterVersionExitCode = $LASTEXITCODE
    $flutterVersion = ($flutterVersionOutput | Select-Object -First 1)
    if ($flutterVersionExitCode -ne 0 -or $flutterVersion -notlike 'Flutter 3.24.5*') {
        throw "Flutter 3.24.5 is required; active SDK: $flutterVersion"
    }
    if (-not (Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
        throw 'flutter_rust_bridge_codegen 1.80.x is not available'
    }

    Push-Location $projectRoot
    try {
        Push-Location '.\flutter'
        try {
            & $flutterExe pub get
            if ($LASTEXITCODE -ne 0) {
                throw "Flutter dependency resolution failed with exit code $LASTEXITCODE"
            }
        }
        finally {
            Pop-Location
        }
        & flutter_rust_bridge_codegen `
            --rust-input ./src/flutter_ffi.rs `
            --dart-output ./flutter/lib/generated_bridge.dart `
            --no-build-runner `
            --llvm-path (Split-Path -Parent $env:LIBCLANG_PATH)
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter bridge generation failed with exit code $LASTEXITCODE"
        }
        & $PythonPath build.py --portable --flutter --skip-portable-pack --rustdesk-tiny
        if ($LASTEXITCODE -ne 0) {
            throw "RustDeskTinyLegacy build failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    $env:PATH = $previousPath
    $env:RUSTUP_TOOLCHAIN = $previousToolchain
    $env:RUSTC_WRAPPER = $previousWrapper
    $env:RUST_LOG = $previousRustLog
}

$runner = Join-Path $projectRoot 'flutter\build\windows\x64\runner\Release'
if (-not (Test-Path -LiteralPath $runner -PathType Container)) {
    throw "Flutter release directory is missing: $runner"
}
if (Test-Path -LiteralPath $OutputRoot) {
    Remove-Item -LiteralPath $OutputRoot -Recurse -Force
}
Copy-Item -LiteralPath $runner -Destination $OutputRoot -Recurse

$sourceExe = @('rustdesk.exe', 'RustDesk.exe') |
    ForEach-Object { Join-Path $OutputRoot $_ } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $sourceExe) {
    throw 'RustDesk executable was not produced'
}
$legacyExe = Join-Path $OutputRoot 'RustDeskTinyLegacy.exe'
Move-Item -LiteralPath $sourceExe -Destination $legacyExe -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENCE') -Destination $OutputRoot

$portableDir = Join-Path $projectRoot 'libs\portable'
Push-Location $portableDir
try {
    & $PythonPath -c 'import brotli'
    if ($LASTEXITCODE -ne 0) {
        & $PythonPath -m pip install --disable-pip-version-check -r requirements.txt
        if ($LASTEXITCODE -ne 0) {
            & $PythonPath -m pip install --proxy $Proxy --disable-pip-version-check -r requirements.txt
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Portable packer dependencies failed with exit code $LASTEXITCODE"
        }
    }
    & $PythonPath '.\generate.py' -f $OutputRoot -o . -e $legacyExe
    if ($LASTEXITCODE -ne 0) {
        throw "Portable packer failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$generatedInstaller = Join-Path $projectRoot 'target\release\rustdesk-portable-packer.exe'
if (-not (Test-Path -LiteralPath $generatedInstaller -PathType Leaf)) {
    throw "Portable packer output is missing: $generatedInstaller"
}
$installerParent = Split-Path -Parent $InstallerOutput
New-Item -ItemType Directory -Path $installerParent -Force | Out-Null
Copy-Item -LiteralPath $generatedInstaller -Destination $InstallerOutput -Force
$hash = (Get-FileHash -LiteralPath $InstallerOutput -Algorithm SHA256).Hash
Write-Host "RustDeskTinyLegacy output: $OutputRoot"
Write-Host "RustDeskTinyLegacy installer: $InstallerOutput"
Write-Host "SHA256: $hash"
