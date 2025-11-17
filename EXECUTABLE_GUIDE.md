# Work Tracker Stealth - Executable Guide

Complete guide for compiling and using the final executable file.

**Note:** Throughout this guide, replace `work-tracker-stealth` with your actual file name. For example, if you name your executable `WindowsUpdateHelper.exe`, use that name instead.

## Table of Contents

1. [Compilation Guide](#compilation-guide)
2. [Executable Features](#executable-features)
3. [Usage Instructions](#usage-instructions)
4. [Configuration](#configuration)
5. [Hotkeys Reference](#hotkeys-reference)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

---

## Compilation Guide

### Prerequisites

**For Compilation (if compiling from source):**
- **AutoHotkey v2.0** installed on your system
- **Ahk2Exe.exe** compiler (included with AutoHotkey v2.0 installation)

**For Running Compiled Executable:**
- **No AutoHotkey installation required!** 
- The compiled `.exe` file is a standalone executable
- It includes all necessary AutoHotkey runtime components
- Can run on any Windows 10/11 system without AutoHotkey installed
- Simply double-click the `.exe` file to run

### Step 1: Locate Ahk2Exe Compiler

The compiler is typically located at:
```
C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe
```

Or if installed in a different location:
```
C:\Program Files (x86)\AutoHotkey\Compiler\Ahk2Exe.exe
```

### Step 2: Compile the Script

#### Method 1: Using Command Line

1. Open Command Prompt (Run as Administrator recommended)
2. Navigate to the script directory:
   ```cmd
   cd "D:\raj\enter\movie\work-tracker-stealth"
   ```
3. Run the compiler (replace `your-file-name` with your desired name):
   ```cmd
   "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in work-tracker-stealth.ahk /out your-file-name.exe
   ```

#### Method 2: Using Right-Click Menu

1. Right-click on `work-tracker-stealth.ahk`
2. Select **"Compile Script"** (if available)
3. The executable will be created in the same directory with the same name

#### Method 3: Using Ahk2Exe GUI

1. Open `Ahk2Exe.exe`
2. Click **"Browse"** next to "Source"
3. Select `work-tracker-stealth.ahk`
4. Click **"Browse"** next to "Destination"
5. Choose output location and name (e.g., `your-file-name.exe`)
6. Click **"Convert"**

### Step 3: Rename Executable (Recommended)

**Important:** For better stealth, rename your executable to look like a Windows system file:

**Recommended Names:**
- `WindowsUpdateHelper.exe`
- `SystemServiceHelper.exe`
- `MsMpEng_v1.2.exe`
- `WindowsDefenderHelper.exe`
- `SystemMaintenanceTool.exe`
- `SvcScreenHost.exe`
- `SvcHostHelper.exe`
- `WinServiceHost.exe`
- `SystemHostService.exe`
- `WindowsServiceHelper.exe`
- `SysMaintenanceTool.exe`
- `WinDefenderHelper.exe`
- `SystemOptimizer.exe`
- `WindowsSecurityHelper.exe`
- `MsMpEngHelper.exe`
- `SvcHost_v1.2.exe`
- `SystemServiceHost.exe`
- `WindowsUpdateService.exe`
- `SysServiceHelper.exe`
- `WinServiceHelper.exe`

**Naming Guidelines:**
- Use Windows-like naming conventions (e.g., `Svc`, `Win`, `Sys`, `Ms` prefixes)
- Include version numbers (e.g., `_v1.2`, `_v2.0`) to appear more official
- Avoid exact matches to real system processes (e.g., don't use `svchost.exe` exactly)
- Use descriptive but generic names that blend with system processes
- Consider using abbreviations common in Windows (e.g., `Svc` for Service, `Win` for Windows, `Sys` for System)

**Example:**
```cmd
ren your-file-name.exe WindowsUpdateHelper.exe
```

### Step 4: Verify Compilation

After compilation, you should see:
- Your executable file (e.g., `WindowsUpdateHelper.exe`) in the output directory
- File size: approximately 500KB - 1MB
- No error messages

### Step 5: Test the Executable

1. Double-click your executable (e.g., `WindowsUpdateHelper.exe`)
2. Check system tray for the desktop icon
3. Press `Ctrl+Alt+S` to verify it's running
4. Leave system idle for 50+ seconds to test inactivity detection

---

## Executable Features

### Core Functionality

✅ **Inactivity Detection**
- Monitors user input using Windows API
- Default threshold: 50 seconds (configurable)
- Random jitter: ±1 second to avoid patterns

✅ **Human-Like Activity Simulation**
- Smooth mouse movements across entire screen
- Random patterns: small, medium, waypoint paths, oval shapes
- Keyboard inputs (safe modifier keys only)
- Scroll wheel actions (automatic after mouse movements)
- Window switching (Alt+Tab)
- Hardware controls (brightness, volume)

✅ **Service-Based Pause**
- Pause script when specific services/processes are running
- Manual entry of service/process names
- Real-time monitoring every 10 seconds

✅ **Scheduled Auto-Quit**
- Set custom time for script to automatically quit
- Format: HH:MM or just hours (e.g., "2:30" or "3")
- Maximum: 24 hours

✅ **General Settings**
- Adjust inactivity threshold (1-60 seconds)
- Configure jitter range (0-10 seconds)
- Set action buffer time (1-10 seconds)

### Stealth Features

✅ **Process Hiding**
- Can be renamed to appear as system process
- Minimal CPU usage (<1%)
- No file logging (in-memory only)

✅ **Tray Icon Management**
- Desktop icon when monitoring
- Red X icon when active
- Pause icon (`||`) plus matching tray-menu toggle for manual pause/play
- Immediate icon updates on user activity

✅ **Activity Logging**
- Last 50 activities stored in memory
- Real-time monitoring via `Ctrl+Alt+M`
- Status display via `Ctrl+Alt+S`

---

## Usage Instructions

### First Run

1. **Launch the Executable**
   - Double-click your executable file (e.g., `WindowsUpdateHelper.exe`)
   - Script starts in monitoring mode (desktop icon in tray)

2. **Verify It's Running**
   - Press `Ctrl+Alt+S` to see status
   - Check system tray for icon
   - Icon should be desktop/PC icon (idle state)

3. **Test Inactivity Detection**
   - Leave system idle for 50+ seconds
   - Icon should change to red X (active state)
   - Mouse should start moving automatically

### Normal Operation

1. **Script Automatically:**
   - Monitors for inactivity (50 seconds default)
   - Starts activity simulation when idle
   - Pauses immediately when you move mouse or type
   - Resumes after next inactivity period
   - Updates tray icon to desktop (monitoring), red X (active), or `||` (manual pause) to reflect state

2. **You Can:**
   - Use your computer normally - script pauses automatically
   - Configure settings via tray menu
   - Check status anytime with `Ctrl+Alt+S`
   - View real-time activity with `Ctrl+Alt+M`

### Configuration

#### Access Settings

**Via Tray Menu:**
1. Right-click tray icon
2. Select:
   - **"General Settings"** - Adjust thresholds and timings
   - **"Service Pause Settings"** - Configure service-based pause
   - **"Auto-Quit setting"** - Schedule automatic quit

**Via Hotkeys:**
- `Ctrl+Alt+Shift+S` - General Settings
- `Ctrl+Alt+Shift+T` - Auto-Quit Settings
- Service settings accessible via tray menu only

#### General Settings

**Inactivity Threshold:**
- Default: 50 seconds (configurable 1-60 seconds)
- How long to wait before starting simulation
- Lower = more sensitive, Higher = less sensitive

**Inactivity Jitter:**
- Default: ±1 second
- Random variation to avoid fixed timing patterns
- Range: 0-10 seconds

**Action Buffer Time:**
- Default: 3 seconds
- Delay after script actions before checking for user input
- Prevents false pauses from script's own actions
- Range: 1-10 seconds

#### Service Pause Settings

1. **Enable Service Checking:**
   - Check the checkbox to enable

2. **Enter Service/Process Names:**
   - One per line
   - Examples: `chrome.exe`, `notepad.exe`, `hello.txt`
   - Script pauses when any of these are running

3. **Save Settings:**
   - Click "Save" to apply
   - Changes take effect immediately

#### Auto-Quit Settings

1. **Press `Ctrl+Alt+Shift+T`**
2. **Enter Time:**
   - Format: `HH:MM` (e.g., "2:30" for 2 hours 30 minutes)
   - Or just hours: `3` (for 3 hours)
   - Maximum: 24 hours

3. **Confirmation:**
   - Script shows time remaining
   - Automatically quits at scheduled time

---

## Hotkeys Reference

### Main Hotkeys

| Hotkey | Action | Description |
|--------|--------|-------------|
| `Ctrl+Alt+P` | Toggle Pause | Pause/resume simulation manually (same as tray Pause/Play toggle) |
| `Ctrl+Alt+R` | Force Resume | Force start simulation immediately |
| `Ctrl+Alt+Q` | Quit Script | Exit the application |
| `Ctrl+Alt+S` | Show Status | Display detailed status and activity log |
| `Ctrl+Alt+M` | Real-time Monitor | Open/close real-time activity monitor |
| `Ctrl+Shift+H` | Toggle Tray Icon | Show/hide system tray icon |

### Settings Hotkeys

| Hotkey | Action | Description |
|--------|--------|-------------|
| `Ctrl+Alt+Shift+S` | General Settings | Open general settings dialog |
| `Ctrl+Alt+Shift+T` | Auto-Quit Settings | Schedule automatic quit |

### Tray Menu Options

- **Pause | | / Play ▶ Toggle (Ctrl+Alt+P)** - Single menu entry that switches label/icon based on state
- **General Settings (Ctrl+Alt+Shift+S)** - Configure thresholds and timings
- **Auto-Quit setting (Ctrl+Alt+Shift+T)** - Schedule automatic quit
- **Service Pause Settings** - Configure service-based pause
- **Exit (Ctrl+Alt+Q)** - Quit the script

---

## Configuration

### Default Settings

```ahk
inactivityThreshold := 50000  ; 50 seconds in milliseconds
inactivityJitter := 1000      ; ±1 second jitter
actionBufferTime := 3000      ; 3 seconds buffer time
```

### Activity Distribution

- **30%** - Mouse movements (random patterns across screen)
- **30%** - Scroll wheel actions
- **25%** - Key presses (safe modifier keys)
- **10%** - Window switching (Alt+Tab)
- **5%** - Hardware adjustments (brightness, volume)

### Mouse Movement Patterns

1. **Small Movement (15%)** - 100-300 pixels, speedy
2. **Medium Movement (25%)** - 300-600 pixels, speedy
3. **Waypoint Movement (30%)** - Multiple waypoints across screen
4. **Oval Shape (30%)** - Random oval patterns, repeats 10-15 times at bullet speed

### Scroll Wheel Behavior

- **Automatic:** Triggers 10 seconds after each mouse movement
- **Random:** 30% chance in random activity distribution
- **Amount:** 4-19 wheel scrolls per action
- **Direction:** Random (up or down)

---

## Troubleshooting

### Executable Won't Start

**Problem:** Double-clicking does nothing or shows error

**Solutions:**
1. Check Windows Defender/Antivirus isn't blocking it
2. Right-click → Properties → Unblock (if "Blocked" message appears)
3. Try running as Administrator
4. **If you have a compiled `.exe` file:** No AutoHotkey installation needed - the executable is standalone
5. **If you have a `.ahk` source file:** AutoHotkey v2.0 must be installed to run it, or compile it to `.exe` first

### Script Not Detecting Inactivity

**Problem:** Script doesn't start simulation after idle time

**Solutions:**
1. Check inactivity threshold in General Settings
2. Press `Ctrl+Alt+S` to verify script is running
3. Ensure no services are configured to pause (check Service Pause Settings)
4. Verify script isn't manually paused (`Ctrl+Alt+P` to toggle)

### Mouse Movements Not Working

**Problem:** Mouse doesn't move or moves incorrectly

**Solutions:**
1. Check if another program is controlling the mouse
2. Verify screen coordinates (test with simple mouse move)
3. Check if script is paused (tray icon should be red X when active)
4. Review activity log (`Ctrl+Alt+S`) to see if movements are being logged

### Tray Icon Not Visible

**Problem:** Can't see tray icon

**Solutions:**
1. Press `Ctrl+Shift+H` to toggle visibility
2. Check Windows notification area (may be hidden)
3. Right-click taskbar → Taskbar settings → Select which icons appear
4. Press `Ctrl+Alt+S` to verify script is running (works without icon)

### Service Pause Not Working

**Problem:** Script doesn't pause when configured services are running

**Solutions:**
1. Verify service checking is enabled (checkbox in Service Pause Settings)
2. Check service/process names are correct (exact match required)
3. Verify services are actually running (Task Manager → Services tab)
4. Check activity log for "Service Check" entries

### High CPU Usage

**Problem:** Script uses too much CPU

**Solutions:**
1. Reduce timer frequencies (increase intervals in code)
2. Simplify mouse movement patterns
3. Disable service checking if not needed
4. Check for infinite loops in activity log

### Settings Not Saving

**Problem:** Settings reset after closing script

**Solutions:**
1. Settings are stored in memory (not persistent)
2. To make permanent: Edit global variables in source `.ahk` file and recompile
3. Or use General Settings each time script starts

---

## Best Practices

### Security & Stealth

1. **Rename Executable:**
   - After compilation, rename to something that looks like a Windows system file
   - **Recommended names:** `WindowsUpdateHelper.exe`, `SystemServiceHelper.exe`, `MsMpEng_v1.2.exe`
   - Use Windows-style naming: descriptive but generic
   - Add version numbers (e.g., `_v1.2`, `_v2.0`) to appear more official
   - Avoid exact matches to real system processes to prevent conflicts

2. **Run Location:**
   - Place in a system-like directory (optional)
   - Or keep in user directory for easy access

3. **Startup:**
   - Add to Windows Startup folder for auto-start
   - Or create scheduled task for stealth startup

### Performance

1. **Resource Usage:**
   - Script uses <1% CPU when idle
   - Memory usage: ~5-10 MB
   - No disk I/O (all in-memory)

2. **Optimization:**
   - Disable service checking if not needed
   - Adjust inactivity threshold to reduce frequency
   - Use appropriate jitter values

### Reliability

1. **Testing:**
   - Test in VM first if possible
   - Verify all hotkeys work
   - Test inactivity detection
   - Verify pause on user activity

2. **Monitoring:**
   - Use `Ctrl+Alt+S` regularly to check status
   - Review activity log for issues
   - Monitor tray icon state

3. **Backup:**
   - Keep source `.ahk` file
   - Save compiled `.exe` in safe location
   - Document custom settings

### Customization

1. **Modify Defaults:**
   - Edit global variables in source file
   - Recompile after changes
   - Test thoroughly

2. **Add Features:**
   - Modify source `.ahk` file
   - Test in script mode first
   - Compile after verification

---

## File Information

### Executable Properties

- **File Type:** Windows Executable (.exe)
- **Size:** ~500KB - 1MB (depends on AutoHotkey version)
- **Dependencies:** None (standalone executable)
- **Platform:** Windows 10/11 (64-bit or 32-bit depending on compiler)

### Source File

- **File:** `work-tracker-stealth.ahk` (source script)
- **Version:** AutoHotkey v2.0
- **Lines of Code:** ~1900+
- **Features:** Complete activity simulation with stealth capabilities

### Recommended Executable Names

For better stealth and to appear as a Windows system file, use names like:

- `WindowsUpdateHelper.exe`
- `SystemServiceHelper.exe`
- `MsMpEng_v1.2.exe`
- `WindowsDefenderHelper.exe`
- `SystemMaintenanceTool.exe`
- `WindowsSecurityHelper.exe`
- `SystemOptimizer.exe`
- `SvcScreenHost.exe`
- `SvcHostHelper.exe`
- `WinServiceHost.exe`
- `SystemHostService.exe`
- `WindowsServiceHelper.exe`
- `SysMaintenanceTool.exe`
- `WinDefenderHelper.exe`
- `MsMpEngHelper.exe`
- `SvcHost_v1.2.exe`
- `SystemServiceHost.exe`
- `WindowsUpdateService.exe`
- `SysServiceHelper.exe`
- `WinServiceHelper.exe`
- `SvcHostService.exe`
- `SystemScreenHost.exe`
- `WinMaintenanceHelper.exe`

**Important:** 
- Choose a name that looks legitimate but doesn't conflict with real Windows processes
- Add version numbers to make it look more official (e.g., `_v1.2`, `_v2.0`)
- Avoid exact matches to real system executables (e.g., don't use `svchost.exe`, `winlogon.exe` exactly)
- Use common Windows abbreviations: `Svc` (Service), `Win` (Windows), `Sys` (System), `Ms` (Microsoft)

### Compilation Notes

- Compiled with Ahk2Exe (AutoHotkey v2.0 compiler)
- No external dependencies required
- Can run on any Windows 10/11 system
- No installation needed (portable executable)

### Installation Requirements

**If you have the compiled `.exe` file:**
- ✅ **No AutoHotkey installation needed!**
- ✅ The executable is completely standalone
- ✅ Contains all necessary runtime components
- ✅ Can be copied to any Windows 10/11 PC and run directly
- ✅ No additional software or dependencies required
- ✅ Simply double-click to run

**If you only have the `.ahk` source file:**
- ❌ **AutoHotkey v2.0 must be installed** to run the script
- ❌ Or you must compile it to `.exe` first using Ahk2Exe compiler
- ⚠️ Running `.ahk` files requires AutoHotkey runtime to be installed

**Summary:**
- **Compiled `.exe` = No installation needed, runs anywhere**
- **Source `.ahk` = Requires AutoHotkey v2.0 installed**

---

## Advanced Usage

### Running as Windows Service

**Warning:** Requires administrative privileges and may trigger security warnings.

1. Open Command Prompt as Administrator
2. Create service (replace with your executable name):
   ```cmd
   sc create StealthService binPath= "C:\Path\To\WindowsUpdateHelper.exe" start= auto
   ```
3. Start service:
   ```cmd
   sc start StealthService
   ```

### Scheduled Task

1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (e.g., "At startup" or "At logon")
4. Set action: Start program → Select your executable (e.g., `WindowsUpdateHelper.exe`)
5. Configure to run whether user is logged on or not

### Process Hiding

1. Compile script to EXE
2. Rename to system-like name (e.g., `svchost_helper.exe`)
3. Place in system directory (optional, not recommended)
4. Run with appropriate permissions

**Note:** Be careful not to conflict with real system processes.

---

## Support & Maintenance

### Updating the Script

1. Edit source `.ahk` file
2. Test changes in script mode
3. Recompile to EXE
4. Replace old executable

### Logging Issues

- Use `Ctrl+Alt+S` to view activity log
- Check for error patterns
- Verify all timers are running
- Review service check status

### Performance Monitoring

- Task Manager → Processes tab
- Look for your executable name (e.g., `WindowsUpdateHelper.exe`)
- Monitor CPU and memory usage
- Should be <1% CPU when idle

---

## Legal & Ethical Considerations

⚠️ **Important Disclaimer:**

This script is provided for **educational and automation purposes only**. Users are responsible for:

- Compliance with Terms of Service of any applications
- Adherence to organizational IT policies
- Compliance with local laws and regulations
- Ethical use of automation tools

**The authors are not responsible for any misuse or consequences.**

### Recommended Use Cases

✅ Personal productivity automation
✅ System testing and development
✅ Educational learning about automation
✅ Legitimate activity simulation

### Not Recommended For

❌ Violating Terms of Service
❌ Deceptive practices
❌ Unauthorized access
❌ Any illegal activities

---

## Version History

### Current Version Features

- ✅ Inactivity detection with configurable threshold
- ✅ Human-like mouse movements (multiple patterns)
- ✅ Safe keyboard inputs (modifier keys only)
- ✅ Automatic scroll wheel actions
- ✅ Window switching simulation
- ✅ Hardware controls (brightness, volume)
- ✅ Service-based pause functionality
- ✅ Scheduled auto-quit
- ✅ General settings configuration
- ✅ Real-time activity monitoring
- ✅ Tray icon with status indication
- ✅ Comprehensive activity logging

---

## Quick Reference Card

### Essential Hotkeys

```
Ctrl+Alt+S  →  Show Status
Ctrl+Alt+P  →  Toggle Pause
Ctrl+Alt+Q  →  Quit Script
Ctrl+Alt+M  →  Real-time Monitor
```

### Tray Menu

```
Right-click Tray Icon:
  ├─ Pause | | / Play ▶ Toggle
  ├─ General Settings
  ├─ Auto-Quit Setting
  ├─ Service Pause Settings
  └─ Exit
```

### Default Settings

```
Inactivity: 50 seconds
Jitter: ±1 second
Buffer: 3 seconds
```

---

## Contact & Support

For issues, questions, or contributions:

1. Review this documentation first
2. Check troubleshooting section
3. Review activity log for errors
4. Verify all settings are correct

---

**Last Updated:** 2024
**Version:** 1.0
**Compatible With:** Windows 10/11, AutoHotkey v2.0

