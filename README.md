# Desktop Switcher

Jump straight to any Windows virtual desktop with **Ctrl + Win + number**, with a smooth fade transition instead of sliding through every desktop in between.

![Demo: jumping between desktops with Ctrl + Win + number](docs/demo.gif)

| Shortcut | Action |
|---|---|
| `Ctrl + Win + 1` … `9` | Go to desktop 1 … 9 |
| `Ctrl + Win + 0` | Go to desktop 10 |
| `Ctrl + Win + ←` / `→` | Unchanged (Windows default) |

If you press a number higher than the desktops you have, it goes to the last one.

## Requirements

- **Windows 11 24H2 or newer** (see [Windows 10 / older Windows 11](#windows-10--older-windows-11) below)
- **[AutoHotkey v2](https://www.autohotkey.com/)** (v1 will not work)

## Install

### Quick install (recommended)

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/gurusanjay2322/DesktopSwitcher/main/install.ps1 | iex
```

This installs AutoHotkey v2 (via winget) if you don't have it, copies Desktop Switcher to `%LOCALAPPDATA%\DesktopSwitcher`, makes it start with Windows, and starts it. A green **H** icon appears in the system tray.

Make sure you have more than one desktop (**Win + Tab → New desktop**), then try `Ctrl + Win + 2`.

### From the zip

1. Download `DesktopSwitcher.zip` from the [latest release](https://github.com/gurusanjay2322/DesktopSwitcher/releases/latest) and extract it.
2. Double-click `install.cmd`.

### Manual

1. Install [AutoHotkey v2](https://www.autohotkey.com/) (`winget install AutoHotkey.AutoHotkey`).
2. Download the release zip or clone this repo. Keep `DesktopSwitcher.ahk` and `VirtualDesktopAccessor.dll` in the same folder.
3. Double-click `DesktopSwitcher.ahk`.
4. To start it with Windows: press **Win + R**, type `shell:startup`, and put a shortcut to `DesktopSwitcher.ahk` in the folder that opens.

### Stop or uninstall

- Stop: right-click the tray **H** icon → **Exit**.
- Uninstall (if you used the installer):
  ```powershell
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/gurusanjay2322/DesktopSwitcher/main/install.ps1))) -Uninstall
  ```
  This stops it, removes the startup shortcut and deletes `%LOCALAPPDATA%\DesktopSwitcher`. AutoHotkey itself is left installed.

## Customizing the transition

Open `DesktopSwitcher.ahk` in a text editor (installed copy: `%LOCALAPPDATA%\DesktopSwitcher`), change the values near the top, then right-click the tray icon → **Reload Script**.

| Setting | Default | What it does |
|---|---|---|
| `FADE_ENABLED` | `true` | `false` switches instantly with no fade |
| `FADE_IN_MS` | `220` | How long the screen takes to dim (ms) |
| `FADE_HOLD_MS` | `80` | Pause at the darkest point while the desktop switches (ms) |
| `FADE_OUT_MS` | `320` | How long the new desktop takes to fade in (ms) |
| `FADE_MAX_OPACITY` | `235` | Darkness at the peak, `0`–`255` |
| `SHOW_LABEL` | `true` | Show "Desktop N" during the switch |

## Troubleshooting

- **It slides through every desktop instead of jumping directly.** The DLL didn't load: check that `VirtualDesktopAccessor.dll` is in the same folder as the script and matches your Windows version (see below).
- **Double-clicking the script opens a text editor.** Right-click it → **Open with → AutoHotkey**.
- **`Ctrl + Win + number` used to open taskbar apps.** That Windows shortcut is replaced while the script runs. Exit the script to get it back.

## Windows 10 / older Windows 11

The bundled `VirtualDesktopAccessor.dll` is the Windows 11 24H2+ build. For other versions, download the matching `VirtualDesktopAccessor.dll` from the [VirtualDesktopAccessor releases](https://github.com/Ciantic/VirtualDesktopAccessor/releases) and replace the one in this folder. After a major Windows update, check there for a newer build if the script stops jumping directly.

## How it works

- The direct jump and the fade overlay use [VirtualDesktopAccessor](https://github.com/Ciantic/VirtualDesktopAccessor) to switch to a desktop by number and to pin the overlay so it stays visible across the switch.
- The overlay is a click-through dark window, created once and hidden between switches. It's 1px shorter than the screen so Windows doesn't treat it as a fullscreen app, which would briefly blank the display.
- If the DLL is missing, the script falls back to reading the current desktop from the registry and sending `Ctrl + Win + ←/→` the right number of times.

## Credits

- [VirtualDesktopAccessor](https://github.com/Ciantic/VirtualDesktopAccessor) by Jari Pennanen, MIT licensed. See `VirtualDesktopAccessor-LICENSE.txt`.

## License

[MIT](LICENSE)
