<#
    Read-only diagnostic for building the 32-bit iRidiDesk release on Windows.
    It does not download, install, modify, or compile anything.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param(
        [string]$Name,
        [ValidateSet('OK', 'MISSING', 'WARNING')][string]$Status,
        [string]$Details
    )
    $script:checks.Add([PSCustomObject]@{
        Check = $Name
        Status = $Status
        Details = $Details
    })
}

function Find-CommandPath {
    param([string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    return $null
}

Write-Host 'iRidiDesk: проверка среды сборки (сборка не запускается)' -ForegroundColor Cyan
Write-Host "Project: $projectRoot"
Write-Host ''

$osBits = if ([Environment]::Is64BitOperatingSystem) { '64' } else { '32' }
Add-Check 'Windows' 'OK' ("{0}; {1}-bit" -f [Environment]::OSVersion.VersionString, $osBits)

$git = Find-CommandPath 'git.exe'
if ($git) {
    Add-Check 'Git for Windows' 'OK' ((& $git --version 2>&1 | Select-Object -First 1) + " ($git)")
}
else {
    Add-Check 'Git for Windows' 'MISSING' 'Install Git for Windows and reopen PowerShell.'
}

$rustup = Find-CommandPath 'rustup.exe'
$cargo = Find-CommandPath 'cargo.exe'
if ($rustup -and $cargo) {
    $cargoOutput = @(& $cargo --version 2>&1 | ForEach-Object { [string]$_ })
    $cargoVersion = $cargoOutput -join ' '
    if ($LASTEXITCODE -eq 0) {
        Add-Check 'Rustup and Cargo' 'OK' ($cargoVersion.Trim() + " ($cargo)")
    }
    else {
        Add-Check 'Rustup and Cargo' 'WARNING' ("Cargo returned an error: {0}" -f $cargoVersion.Trim())
    }

    $toolchain = 'stable-x86_64-pc-windows-msvc'
    $toolchains = & $rustup toolchain list 2>&1
    if ($toolchains -match [regex]::Escape($toolchain)) {
        Add-Check 'Rust x64 MSVC host toolchain' 'OK' $toolchain
        $targets = & $rustup target list --toolchain $toolchain --installed 2>&1
        if ($targets -contains 'i686-pc-windows-msvc') {
            Add-Check 'Rust 32-bit target' 'OK' 'i686-pc-windows-msvc'
        }
        else {
            Add-Check 'Rust 32-bit target' 'MISSING' "Run: rustup target add i686-pc-windows-msvc --toolchain $toolchain"
        }
    }
    else {
        Add-Check 'Rust x64 MSVC host toolchain' 'MISSING' "Run: rustup toolchain install $toolchain"
        Add-Check 'Rust 32-bit target' 'WARNING' 'Check it after installing the x64 MSVC host toolchain.'
    }
}
else {
    Add-Check 'Rustup and Cargo' 'MISSING' 'Install Rust using rustup, then reopen PowerShell.'
    Add-Check 'Rust x64 MSVC host toolchain' 'WARNING' 'Cannot check until Rust is installed.'
    Add-Check 'Rust 32-bit target' 'WARNING' 'Cannot check until Rust is installed.'
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsInstallations = @()
if (Test-Path -LiteralPath $vswhere) {
    $vsInstallations = @(& $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json | ConvertFrom-Json)
}

if ($vsInstallations.Count -eq 0) {
    Add-Check 'Visual Studio C++ tools' 'MISSING' 'Install the Desktop development with C++ workload, including MSVC v143 x64/x86 tools and a Windows SDK.'
}

else {
    foreach ($vs in $vsInstallations) {
        $msvcRoot = Join-Path $vs.installationPath 'VC\Tools\MSVC'
        $msvc = Get-ChildItem -LiteralPath $msvcRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                (Test-Path (Join-Path $_.FullName 'bin\Hostx64\x64\link.exe')) -and
                (Test-Path (Join-Path $_.FullName 'lib\x64\msvcrt.lib')) -and
                (Test-Path (Join-Path $_.FullName 'lib\x86\msvcrt.lib'))
            } |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($msvc) {
            Add-Check 'Visual Studio C++ tools' 'OK' ("{0}; MSVC {1}; {2}" -f $vs.displayName, $msvc.Name, $vs.installationPath)
        }
        else {
            Add-Check 'Visual Studio C++ tools' 'MISSING' ("{0}; add MSVC v143 C++ x64/x86 build tools." -f $vs.displayName)
        }
    }
}

$releaseScriptVsPath = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat'
if (Test-Path -LiteralPath $releaseScriptVsPath) {
    Add-Check 'Release script compatibility' 'OK' 'The current release script can find Visual Studio Build Tools.'
}
else {
    Add-Check 'Release script compatibility' 'WARNING' 'C++ tools exist, but the current release script expects Visual Studio 2022 Build Tools at its default path. Send this report before building.'
}

$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$sdk = Get-ChildItem -LiteralPath $sdkRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'x64\rc.exe') } |
    Sort-Object Name -Descending |
    Select-Object -First 1
if ($sdk) {
    Add-Check 'Windows SDK' 'OK' ("Version {0}" -f $sdk.Name)
}
else {
    Add-Check 'Windows SDK' 'MISSING' 'Install a Windows 10 or Windows 11 SDK through Visual Studio Installer.'
}

$envFile = Join-Path $projectRoot '.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    Add-Check 'Local server configuration (.env)' 'MISSING' 'Create .env from .env.example. Do not add .env to Git.'
}
else {
    $names = Get-Content -LiteralPath $envFile | ForEach-Object {
        if ($_ -match '^\s*(IRIDI_(?:RENDEZVOUS_SERVER|RELAY_SERVER|PUB_KEY))\s*=\s*(.+)\s*$') { $Matches[1] }
    }
    $required = @('IRIDI_RENDEZVOUS_SERVER', 'IRIDI_RELAY_SERVER', 'IRIDI_PUB_KEY')
    $absent = @($required | Where-Object { $_ -notin $names })
    if ($absent.Count -eq 0) {
        Add-Check 'Local server configuration (.env)' 'OK' 'Required values are present (values are deliberately not printed).'
    }
    else {
        Add-Check 'Local server configuration (.env)' 'MISSING' ('Missing: ' + ($absent -join ', '))
    }
}

Write-Host 'Result:' -ForegroundColor Cyan
$checks | Format-Table -AutoSize -Wrap

$blocking = @($checks | Where-Object { $_.Status -in @('MISSING', 'WARNING') })
if ($blocking.Count -eq 0) {
    Write-Host 'Environment is ready for the release script.' -ForegroundColor Green
    exit 0
}

Write-Host 'Environment is not ready yet. Send the complete table above to Codex.' -ForegroundColor Yellow
exit 1
