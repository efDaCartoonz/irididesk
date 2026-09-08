param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'

if (-not (Test-Path -LiteralPath $envFile)) {
    throw 'Create a local .env from .env.example before building. Do not commit it.'
}

Get-Content -LiteralPath $envFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $match = [regex]::Match($line, '^(?<name>IRIDI_[A-Z_]+)=(?<value>.*)$')
    if ($match.Success) {
        Set-Item -Path ("Env:" + $match.Groups['name'].Value) -Value $match.Groups['value'].Value
    }
}

$required = @('IRIDI_RENDEZVOUS_SERVER', 'IRIDI_RELAY_SERVER', 'IRIDI_PUB_KEY')
foreach ($name in $required) {
    if ([string]::IsNullOrWhiteSpace((Get-Item -Path ("Env:" + $name) -ErrorAction SilentlyContinue).Value)) {
        throw "$name is required in .env"
    }
}

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    throw 'Rust toolchain is required. Install Rust, then add i686-pc-windows-msvc with rustup.'
}

$gitCommand = 'C:\Program Files\Git\cmd\git.exe'
if (-not (Test-Path -LiteralPath $gitCommand)) {
    throw 'Git for Windows is required to obtain RustDesk build dependencies.'
}
$env:Path = (Split-Path -Parent $gitCommand) + ';' + $env:Path

Push-Location $projectRoot
try {
    $vcVars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat'
    if (-not (Test-Path -LiteralPath $vcVars)) {
        throw 'Microsoft C++ Build Tools are required for the Windows linker.'
    }
    $msvcRoot = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC'
    $msvc = Get-ChildItem $msvcRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            (Test-Path (Join-Path $_.FullName 'lib\x64\msvcrt.lib')) -and
            (Test-Path (Join-Path $_.FullName 'lib\x86\msvcrt.lib'))
        } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if ($null -eq $msvc) {
        throw 'Install the MSVC v143 C++ x64/x86 build tools component before building.'
    }
    $env:IRIDI_VCVARS_VERSION = ($msvc.Name.Split('.')[0..1] -join '.')
    $env:CARGO_TARGET_I686_PC_WINDOWS_MSVC_LINKER = Join-Path $PSScriptRoot 'link-i686.cmd'
    cmd.exe /d /s /c "call `"$vcVars`" x64 -vcvars_ver=$env:IRIDI_VCVARS_VERSION >nul && cargo +stable-x86_64-pc-windows-msvc build --release --target i686-pc-windows-msvc"
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo build failed with exit code $LASTEXITCODE"
    }

    $source = Join-Path $projectRoot 'target\i686-pc-windows-msvc\release'
    $package = Join-Path $projectRoot 'dist\iRidiDesk-win32'
    $archive = Join-Path $projectRoot ("dist\iRidiDesk-" + $Version + "-win32.zip")

    Remove-Item -LiteralPath $package -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $package -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'rustdesk.exe') -Destination (Join-Path $package 'iRidiDesk.exe')
    Copy-Item -LiteralPath (Join-Path $source 'service.exe') -Destination $package
    Copy-Item -LiteralPath (Join-Path $source 'sciter.dll') -Destination $package
    Copy-Item -LiteralPath (Join-Path $projectRoot 'src\ui') -Destination $package -Recurse

    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    Compress-Archive -LiteralPath (Join-Path $package '*') -DestinationPath $archive -CompressionLevel Optimal
    Write-Host "Release package created: $archive"
}
finally {
    Pop-Location
}
