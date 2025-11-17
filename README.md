# Work Tracker Stealth - AutoHotkey Anti-Detection Script

A highly advanced AutoHotkey v2.0 script designed for human-like activity simulation with comprehensive anti-detection features. This script monitors system inactivity and performs natural mouse movements, keyboard inputs, scroll actions, and window switching to maintain an active presence.

**Developed by [Qwery Technolabs](https://qwerytechnolabs.com)**

## ⚠️ Important Disclaimer

This script is provided for **educational and automation purposes only**. Use responsibly and ensure compliance with:
- Terms of Service of any applications you use this with
- Your organization's IT policies
- Local laws and regulations

**The authors are not responsible for any misuse or consequences of using this script.**

## Features

### Core Functionality
- **Inactivity Detection**: Monitors user input using Windows API (`GetLastInputInfo`) and triggers simulation after ~50 seconds of inactivity (configurable)
- **Human-Like Mouse Movements**: Smooth movements across entire screen with multiple patterns (small, medium, waypoint paths, oval shapes)
- **Random Key Presses**: Safe modifier keys (Ctrl, Alt, Shift) and function keys (F1-F12) to avoid interfering with documents
- **Scroll Wheel Actions**: Automatic scroll actions after mouse movements (10 seconds delay) plus random scroll events
- **Window Switching**: Alt+Tab simulation for realistic activity
- **Hardware Controls**: Brightness and volume adjustments using function keys
- **User Override**: Automatically pauses immediately when user activity is detected
- **Service-Based Pause**: Pause script when specific Windows services/processes are running
- **Scheduled Auto-Quit**: Set custom time for script to automatically quit
- **General Settings**: Configure inactivity threshold, jitter, and action buffer time via GUI
- **Real-Time Monitoring**: View current activity and detailed logs

### Stealth Features
- **Process Hiding**: Instructions for renaming compiled EXE to mimic Windows system processes (e.g., `WindowsUpdateHelper.exe`, `SvcScreenHost.exe`)
- **Tray Icon Management**: Desktop icon while monitoring, red X icon when actively simulating, dedicated pause icon (`||`) plus matching tray-menu toggle that switches between pause/play labels
- **Minimal Footprint**: Low CPU usage (<1%), no file logging, in-memory operations only
- **Multi-Monitor Support**: Automatically detects and works with multiple monitors
- **Activity Logging**: Last 50 activities stored in memory for monitoring

## Requirements

**For Running Source Script (.ahk file):**
- **AutoHotkey v2.0** or later
- **Windows 10/11**

**For Running Compiled Executable (.exe file):**
- **No AutoHotkey installation needed!** The compiled executable is standalone
- **Windows 10/11** only

## Installation

### Option 1: Using Compiled Executable (Recommended)

1. **If you have the compiled `.exe` file:**
   - ✅ **No AutoHotkey installation needed!**
   - Simply double-click the `.exe` file to run
   - The executable is completely standalone and portable
   - Can be copied to any Windows 10/11 PC

2. **Rename for stealth (optional):**
   - Rename to a Windows-style name like `WindowsUpdateHelper.exe` or `SvcScreenHost.exe`
   - See [EXECUTABLE_GUIDE.md](EXECUTABLE_GUIDE.md) for more naming examples

### Option 2: Using Source Script

1. Download and install [AutoHotkey v2.0](https://www.autohotkey.com/download/ahk-v2.exe)

2. Save `work-tracker-stealth.ahk` to your desired location

3. Double-click the `.ahk` file to run

4. (Optional) Compile to EXE:
   - Right-click the `.ahk` file → Select "Compile Script" (if available)
   - Or use command line: `Ahk2Exe.exe /in work-tracker-stealth.ahk /out your-file-name.exe`
   - See [EXECUTABLE_GUIDE.md](EXECUTABLE_GUIDE.md) for detailed compilation instructions

## Usage

### Basic Usage

1. **Run the script**: Double-click your executable (e.g., `WindowsUpdateHelper.exe`) or the source `.ahk` file

2. **The script will**:
   - Start in monitoring mode (desktop icon in system tray)
   - Monitor for user inactivity (default: 50 seconds)
   - Automatically begin simulation when idle
   - Pause immediately when you move the mouse or type
   - Tray icon changes to red X when active, `||` when manually paused, and back to desktop icon when monitoring

3. **Access controls**:
   - Press `Ctrl+Alt+S` to view status and activity log
   - Press `Ctrl+Alt+M` to open real-time activity monitor
   - Right-click the tray icon for menu options, including a single Pause/Play toggle that mirrors `Ctrl+Alt+P`

### Hotkeys

| Hotkey | Action | Description |
|--------|--------|-------------|
| `Ctrl+Alt+P` | Toggle Pause | Pause/resume simulation manually (mirrors tray Pause/Play toggle) |
| `Ctrl+Alt+R` | Force Resume | Force start simulation immediately |
| `Ctrl+Alt+Q` | Quit Script | Exit the application |
| `Ctrl+Alt+S` | Show Status | Display detailed status and activity log |
| `Ctrl+Alt+M` | Real-time Monitor | Open/close real-time activity monitor |
| `Ctrl+Shift+H` | Toggle Tray Icon | Show/hide system tray icon |
| `Ctrl+Alt+Shift+S` | General Settings | Open general settings dialog |
| `Ctrl+Alt+Shift+T` | Auto-Quit Settings | Schedule automatic quit |

### Configuration

#### Via GUI (Recommended)

1. **General Settings** (`Ctrl+Alt+Shift+S`):
   - Adjust inactivity threshold (1-60 seconds)
   - Configure jitter range (0-10 seconds)
   - Set action buffer time (1-10 seconds)

2. **Service Pause Settings** (Tray Menu):
   - Enable/disable service checking
   - Add service/process names to pause when running

3. **Auto-Quit Settings** (`Ctrl+Alt+Shift+T`):
   - Schedule automatic quit (format: HH:MM or hours)
   - Maximum: 24 hours

#### Via Script Editing

Edit global variables in the script:

```ahk
; Inactivity threshold (default: 50 seconds)
inactivityThreshold := 50000

; Jitter range (default: ±1 second)
inactivityJitter := 1000

; Action buffer time (default: 3 seconds)
actionBufferTime := 3000
```

### Mouse Movement Patterns

The script uses four movement patterns across the entire screen:
- **Small Movement (15%)**: 100-300 pixels, speedy
- **Medium Movement (25%)**: 300-600 pixels, speedy
- **Waypoint Movement (30%)**: Multiple waypoints across screen
- **Oval Shape (30%)**: Random oval patterns, repeats 10-15 times at bullet speed

### Activity Distribution

- **30%** - Mouse movements (random patterns across screen)
- **30%** - Scroll wheel actions
- **25%** - Key presses (safe modifier keys)
- **10%** - Window switching (Alt+Tab)
- **5%** - Hardware adjustments (brightness, volume)

### Scroll Wheel Behavior

- **Automatic:** Triggers 10 seconds after each mouse movement
- **Random:** 30% chance in random activity distribution
- **Amount:** 4-19 wheel scrolls per action
- **Direction:** Random (up or down)

## Advanced: Stealth Compilation

### Process Renaming

After compiling to EXE, rename it to appear as a Windows system file:

**Recommended Names:**
- `WindowsUpdateHelper.exe`
- `SystemServiceHelper.exe`
- `SvcScreenHost.exe`
- `SvcHostHelper.exe`
- `WinServiceHost.exe`
- `MsMpEng_v1.2.exe`
- `SystemMaintenanceTool.exe`

**Naming Guidelines:**
- Use Windows-style naming conventions (`Svc`, `Win`, `Sys`, `Ms` prefixes)
- Include version numbers (e.g., `_v1.2`, `_v2.0`)
- Avoid exact matches to real system processes
- See [EXECUTABLE_GUIDE.md](EXECUTABLE_GUIDE.md) for complete list and guidelines

### Running as Service (Advanced)

For deeper hiding, you can run as a Windows service (requires admin):

```cmd
sc create StealthService binPath= "C:\Path\To\WindowsUpdateHelper.exe" start= auto
sc start StealthService
```

**Warning**: This requires administrative privileges and may trigger security warnings.

## Testing & Verification

### Recommended Testing Steps

1. **Test in VM first**: Run in a virtual machine to verify behavior
2. **Monitor with Process Explorer**: Check for resource usage and process visibility
3. **Test inactivity detection**: Leave system idle for 50+ seconds
4. **Test user override**: Move mouse during simulation to verify pause
5. **Verify tray icon changes**: Desktop icon when idle, red X when active
6. **Test settings dialogs**: General Settings, Service Pause Settings, Auto-Quit
7. **Check activity log**: Press `Ctrl+Alt+S` to view activity history

### Monitoring Tools

- **Process Explorer** (Sysinternals): Monitor process behavior
- **Resource Monitor**: Check CPU/memory usage
- **Script Status** (`Ctrl+Alt+S`): Built-in activity log and status display
- **Real-time Monitor** (`Ctrl+Alt+M`): Live activity tracking

## Troubleshooting

### Script Not Starting
- **If using `.exe` file**: No AutoHotkey needed - check Windows Defender/antivirus isn't blocking it
- **If using `.ahk` file**: Ensure AutoHotkey v2.0 is installed
- Right-click → Properties → Unblock (if "Blocked" message appears)
- Try running as administrator if needed

### Mouse Movements Not Working
- Check if another program is controlling the mouse
- Verify screen coordinates (test with simple mouse move)
- Check if script is paused (tray icon should be red X when active)
- Review activity log (`Ctrl+Alt+S`) to see if movements are being logged

### Tray Icon Not Visible
- Press `Ctrl+Shift+H` to toggle visibility
- Check Windows notification area (may be hidden)
- Right-click taskbar → Taskbar settings → Select which icons appear
- Press `Ctrl+Alt+S` to verify script is running (works without icon)

### Service Pause Not Working
- Verify service checking is enabled (checkbox in Service Pause Settings)
- Check service/process names are correct (exact match required)
- Verify services are actually running (Task Manager → Services tab)
- Check activity log for "Service Check" entries

### High CPU Usage
- Reduce timer frequencies (increase intervals in code)
- Simplify mouse movement patterns
- Disable service checking if not needed
- Check for infinite loops in activity log

## Customization

### Via GUI Settings

Use the built-in settings dialogs for easy customization:
- **General Settings** (`Ctrl+Alt+Shift+S`): Adjust thresholds and timings
- **Service Pause Settings** (Tray Menu): Configure service-based pause
- **Auto-Quit Settings** (`Ctrl+Alt+Shift+T`): Schedule automatic quit

### Via Script Editing

Edit global variables in the script for permanent changes:

```ahk
; Inactivity threshold (default: 50 seconds)
inactivityThreshold := 50000

; Jitter range (default: ±1 second)
inactivityJitter := 1000

; Action buffer time (default: 3 seconds)
actionBufferTime := 3000
```

**Note:** Settings changed via GUI are stored in memory and reset when script restarts. For permanent changes, edit the script and recompile.

## Security Considerations

- **No Network Calls**: Script operates entirely offline
- **No File Logging**: All operations are in-memory
- **Minimal Footprint**: Low resource usage to avoid detection
- **User Override**: Always respects user input

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

**Summary:**
- ✅ Free to use, modify, and distribute
- ✅ Commercial use allowed
- ✅ Private use allowed
- ✅ No warranty provided
- ⚠️ Use responsibly and ethically

See [LICENSE](LICENSE) for the full license text.

## Contributing

Feel free to fork and improve:
- Add more movement patterns
- Enhance browser automation
- Improve stealth features
- Optimize performance

## References

Inspired by open-source projects:
- [tdolan21's Enhanced Anti-AFK Gist](https://gist.github.com/tdolan21/bf5bdcc4ff8431539cb2c7181fcf7938)
- [SpaceGT/Anti-AFK](https://github.com/SpaceGT/Anti-AFK)
- [wissemzidi/Anti-AFK](https://github.com/wissemzidi/Anti-AFK)

## Documentation

- **[EXECUTABLE_GUIDE.md](EXECUTABLE_GUIDE.md)**: Complete guide for compiling and using the executable
- **[QUICK_START.md](QUICK_START.md)**: Quick start guide for new users
- **README.md** (this file): Overview and feature documentation

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review [EXECUTABLE_GUIDE.md](EXECUTABLE_GUIDE.md) for detailed information
3. Use `Ctrl+Alt+S` to check script status and activity log
4. Test in a safe environment first

## Key Features Summary

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
✅ **Standalone Executable** - No AutoHotkey needed when compiled  

---

## Credits

**Developed by [Qwery Technolabs](https://qwerytechnolabs.com)**

---

**Remember**: Use responsibly and ethically. This tool is for automation and educational purposes only.

