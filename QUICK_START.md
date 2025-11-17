# Quick Start Guide

## Installation Steps

### Option 1: Using Compiled Executable (Easiest)

1. **If you have the compiled `.exe` file:**
   - ✅ **No AutoHotkey installation needed!**
   - Simply double-click your executable (e.g., `WindowsUpdateHelper.exe`)
   - The script starts automatically

2. **Rename for stealth (optional):**
   - Rename to a Windows-style name like `SvcScreenHost.exe` or `WindowsUpdateHelper.exe`
   - See [EXECUTABLE_GUIDE.md](EXECUTABLE_GUIDE.md) for more examples

### Option 2: Using Source Script

1. **Install AutoHotkey v2.0**
   - Download from: https://www.autohotkey.com/download/ahk-v2.exe
   - Run the installer

2. **Run the Script**
   - Double-click `work-tracker-stealth.ahk`
   - The script starts in monitoring mode (desktop icon in system tray)

3. **How It Works**
   - Script monitors for ~50 seconds of inactivity (configurable)
   - Automatically starts human-like simulation (mouse moves, scroll actions, key presses, window switching)
   - Pauses immediately when you move mouse or type
   - Tray icon changes to red X when active, `||` when manually paused, and back to desktop icon when monitoring
   - Resumes after next inactivity period

## Quick Controls

| Action | Hotkey | Description |
|--------|--------|-------------|
| Show Status | `Ctrl+Alt+S` | View detailed status and activity log |
| Real-time Monitor | `Ctrl+Alt+M` | Open/close real-time activity monitor |
| Pause/Resume | `Ctrl+Alt+P` | Toggle simulation manually (same as tray Pause/Play option) |
| Force Resume | `Ctrl+Alt+R` | Force start simulation immediately |
| Quit Script | `Ctrl+Alt+Q` | Exit the application |
| General Settings | `Ctrl+Alt+Shift+S` | Configure thresholds and timings |
| Auto-Quit Settings | `Ctrl+Alt+Shift+T` | Schedule automatic quit |
| Show/Hide Tray Icon | `Ctrl+Shift+H` | Toggle tray icon visibility |

## Compile to EXE (Optional)

1. Right-click `work-tracker-stealth.ahk`
2. Select "Compile Script" (if available)
3. Or use command line:
   ```
   "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in work-tracker-stealth.ahk /out your-file-name.exe
   ```
4. **Rename for stealth (recommended):**
   - Rename to Windows-style name like `WindowsUpdateHelper.exe` or `SvcScreenHost.exe`
   - See [EXECUTABLE_GUIDE.md](EXECUTABLE_GUIDE.md) for complete naming guide

**Note:** Once compiled, the `.exe` file is standalone and doesn't require AutoHotkey to be installed.

## First Run Checklist

- [ ] Script runs without errors
- [ ] Tray icon appears (desktop icon when idle)
- [ ] Press `Ctrl+Alt+S` to verify status display works
- [ ] Leave system idle for 50+ seconds (or your configured threshold)
- [ ] Verify tray icon changes to red X when active and to `||` when you pause manually
- [ ] Verify mouse moves automatically across screen
- [ ] Verify scroll actions occur after mouse movements
- [ ] Move mouse to verify pause works (icon changes back to desktop)
- [ ] Test hotkeys work correctly
- [ ] Test General Settings (`Ctrl+Alt+Shift+S`)
- [ ] Test Service Pause Settings (Tray Menu → Service Pause Settings)

## Troubleshooting

**Script won't start?**
- **If using `.exe` file:** No AutoHotkey needed - check Windows Defender/antivirus isn't blocking it
- **If using `.ahk` file:** Ensure AutoHotkey v2.0 is installed
- Right-click → Properties → Unblock (if "Blocked" message appears)
- Try running as administrator

**Mouse not moving?**
- Check if another program is controlling mouse
- Verify script is active (tray icon should be red X)
- Check activity log (`Ctrl+Alt+S`) to see if movements are logged
- Ensure script isn't paused (`Ctrl+Alt+P` to toggle)

**Tray icon not visible?**
- Press `Ctrl+Shift+H` to toggle visibility
- Check Windows notification area (may be hidden)
- Press `Ctrl+Alt+S` to verify script is running (works without icon)

**Settings not saving?**
- Settings are stored in memory (reset when script restarts)
- For permanent changes, edit the script and recompile
- Or use General Settings each time script starts

## Customization

### Via GUI (Easiest)

1. **General Settings** (`Ctrl+Alt+Shift+S`):
   - Adjust inactivity threshold (1-60 seconds)
   - Configure jitter range (0-10 seconds)
   - Set action buffer time (1-10 seconds)

2. **Service Pause Settings** (Tray Menu):
   - Enable/disable service checking
   - Add service/process names to pause when running

3. **Auto-Quit Settings** (`Ctrl+Alt+Shift+T`):
   - Schedule automatic quit (format: HH:MM or hours)

### Via Script Editing (Permanent)

Edit these variables in the script for permanent changes:

```ahk
inactivityThreshold := 50000  ; Default: 50 seconds (milliseconds)
inactivityJitter := 1000       ; Default: ±1 second
actionBufferTime := 3000       ; Default: 3 seconds
```

**Note:** Settings changed via GUI are stored in memory and reset when script restarts. For permanent changes, edit the script and recompile.

## Key Features

✅ **Inactivity Detection** - Configurable threshold (default: 50 seconds)  
✅ **Human-Like Mouse Movements** - Multiple patterns across entire screen  
✅ **Scroll Wheel Actions** - Automatic after mouse movements + random events  
✅ **Safe Keyboard Inputs** - Modifier keys and function keys only  
✅ **Window Switching** - Alt+Tab simulation  
✅ **Service-Based Pause** - Pause when specific services/processes run  
✅ **Scheduled Auto-Quit** - Set custom quit time  
✅ **General Settings GUI** - Easy configuration without editing code  
✅ **Real-Time Monitoring** - Activity log and live status display  
✅ **Tray Icon Status** - Visual indication of script state  

## Documentation

- **[EXECUTABLE_GUIDE.md](EXECUTABLE_GUIDE.md)**: Complete guide for compiling and using the executable
- **[README.md](README.md)**: Full feature documentation
- **QUICK_START.md** (this file): Quick start guide

## Safety Notes

- Test in a VM first if possible
- Monitor with Process Explorer
- Use responsibly and ethically
- Comply with all Terms of Service

---

**Remember**: Use responsibly and ethically. This tool is for automation and educational purposes only.

