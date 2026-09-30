# Desktop Switcher installer
#
# Install (latest release):
#   irm https://raw.githubusercontent.com/gurusanjay2322/DesktopSwitcher/main/install.ps1 | iex
# Uninstall:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/gurusanjay2322/DesktopSwitcher/main/install.ps1))) -Uninstall
#
# Run from an extracted release zip, it installs the files next to it instead of downloading.

param(
    [switch]$Uninstall,
    [switch]$NoStartup
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo = 'gurusanjay2322/DesktopSwitcher'
$ZipUrl = "https://github.com/$Repo/releases/latest/download/DesktopSwitcher.zip"
$InstallDir = Join-Path $env:LOCALAPPDATA 'DesktopSwitcher'
$ScriptName = 'DesktopSwitcher.ahk'
$Shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'DesktopSwitcher.lnk'
$Files = @('DesktopSwitcher.ahk', 'VirtualDesktopAccessor.dll', 'LICENSE', 'VirtualDesktopAccessor-LICENSE.txt', 'README.md')

function Stop-DesktopSwitcher {
    Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" |
        Where-Object { $_.CommandLine -like "*$ScriptName*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 300
}

function Find-AutoHotkey {
    $roots = @()
    foreach ($key in 'HKLM:\SOFTWARE\AutoHotkey', 'HKCU:\SOFTWARE\AutoHotkey') {
        $dir = (Get-ItemProperty $key -ErrorAction SilentlyContinue).InstallDir
        if ($dir) { $roots += $dir }
    }
    $roots += (Join-Path $env:ProgramFiles 'AutoHotkey')
    $roots += (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey')
    foreach ($root in $roots) {
        foreach ($exe in 'AutoHotkey64.exe', 'AutoHotkey32.exe') {
            $path = Join-Path $root "v2\$exe"
            if (Test-Path $path) { return $path }
        }
    }
    return $null
}

if ($Uninstall) {
    Write-Host 'Uninstalling Desktop Switcher...'
    Stop-DesktopSwitcher
    Remove-Item $Shortcut -Force -ErrorAction SilentlyContinue
    Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Done. AutoHotkey itself was left installed.' -ForegroundColor Green
    return
}

# 1. AutoHotkey v2
$ahk = Find-AutoHotkey
if (-not $ahk) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'AutoHotkey v2 is not installed and winget is unavailable. Install it from https://www.autohotkey.com/ and run this again.'
    }
    Write-Host 'Installing AutoHotkey v2 with winget...'
    winget install --id AutoHotkey.AutoHotkey -e --silent --accept-package-agreements --accept-source-agreements
    $ahk = Find-AutoHotkey
    if (-not $ahk) { throw 'AutoHotkey v2 install did not finish. Install it from https://www.autohotkey.com/ and run this again.' }
}
Write-Host "Using AutoHotkey: $ahk"

# 2. Get the files: next to this script if run from a release zip, otherwise download the latest release
$source = $null
$temp = $null
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot $ScriptName))) {
    $source = $PSScriptRoot
} else {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ("DesktopSwitcher-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $temp | Out-Null
    $zip = Join-Path $temp 'DesktopSwitcher.zip'
    Write-Host "Downloading $ZipUrl"
    Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $temp -Force
    $found = Get-ChildItem -Path $temp -Filter $ScriptName -Recurse | Select-Object -First 1
    if (-not $found) { throw "$ScriptName not found in the downloaded release." }
    $source = $found.DirectoryName
}

# 3. Copy (stop a running copy first so the DLL isn't locked)
Stop-DesktopSwitcher
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
foreach ($file in $Files) {
    $from = Join-Path $source $file
    if (Test-Path $from) { Copy-Item $from $InstallDir -Force }
}
Get-ChildItem $InstallDir | Unblock-File
if ($temp) { Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue }

$scriptPath = Join-Path $InstallDir $ScriptName

# 4. Start with Windows
if (-not $NoStartup) {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($Shortcut)
    $lnk.TargetPath = $ahk
    $lnk.Arguments = "`"$scriptPath`""
    $lnk.WorkingDirectory = $InstallDir
    $lnk.Description = 'Desktop Switcher'
    $lnk.Save()
    Write-Host 'Added to startup.'
}

# 5. Run it
Start-Process -FilePath $ahk -ArgumentList "`"$scriptPath`"" -WorkingDirectory $InstallDir
Write-Host "Desktop Switcher is installed in $InstallDir and running. Try Ctrl + Win + 2." -ForegroundColor Green
