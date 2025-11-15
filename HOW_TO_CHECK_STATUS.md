# How to Check if Script is Running

## Quick Status Check Methods

### Method 1: Status Hotkey (Easiest)
**Press `Ctrl+Alt+S`** anywhere on your computer
- Shows a popup window with detailed status and activity log
- Displays: Running time, current state, simulation status, activity history
- Works even if tray icon is hidden
- Shows last 50 activities with timestamps

### Method 2: Real-Time Activity Monitor
**Press `Ctrl+Alt+M`** to open/close real-time monitor
- Live activity tracking window
- Shows current activity being performed
- Updates in real-time as script runs
- Can be kept open while using your computer

### Method 3: Tray Icon Status
**Look for the tray icon** in the system tray (bottom-right corner)
- **Desktop/PC icon** = Script is idle/paused (monitoring for inactivity)
- **Red X icon** = Script is active (performing simulation)
- Icon changes immediately when you interact with computer
- Right-click the icon for menu options

**Icon States:**
- 🖥️ Desktop icon = Monitoring/Waiting/Paused
- ❌ Red X icon = Active/Simulating

### Method 4: Task Manager
1. Press `Ctrl+Shift+Esc` to open Task Manager
2. Look for process: `AutoHotkey.exe` or your compiled script name (e.g., `WindowsUpdateHelper.exe`, `SvcScreenHost.exe`)
3. If you see it: Script is running
4. Check CPU usage (should be <1% when idle)

## Status Information Displayed

When you press `Ctrl+Alt+S`, you'll see:

```
=== Script Status ===
Status: ACTIVE / MONITORING / PAUSED
Uptime: Xh Ym Zs
Simulation: Running / Waiting for inactivity
Paused: Yes / No
Inactivity Threshold: 50 seconds
Last Input: X seconds ago
Scheduled Quit: Not set / HH:MM remaining

=== Recent Activity Log ===
HH:MM:SS - Activity Type - Details
... (last 50 activities with timestamps)
```

**Status Display Includes:**
- Current script state (Active/Monitoring/Paused)
- Total uptime since script started
- Simulation status (Running/Waiting)
- Pause state (Yes/No)
- Inactivity threshold setting
- Time since last user input
- Scheduled auto-quit time (if set)
- Complete activity log (last 50 activities)

## All Owner Hotkeys

| Hotkey | Action | Description |
|--------|--------|-------------|
| `Ctrl+Alt+S` | **Show Status** | Display detailed status and activity log (check if running) |
| `Ctrl+Alt+M` | **Real-time Monitor** | Open/close real-time activity monitor window |
| `Ctrl+Alt+P` | Toggle Pause | Pause/resume simulation manually |
| `Ctrl+Alt+R` | Force Resume | Force start simulation immediately |
| `Ctrl+Alt+Q` | Quit Script | Exit the application |
| `Ctrl+Shift+H` | Toggle Tray Icon | Show/hide system tray icon |
| `Ctrl+Alt+Shift+S` | General Settings | Open general settings dialog |
| `Ctrl+Alt+Shift+T` | Auto-Quit Settings | Schedule automatic quit |

## Tray Menu (Right-click tray icon)

- **General Settings (Ctrl+Alt+Shift+S)** - Configure thresholds and timings
- **Auto-Quit setting (Ctrl+Alt+Shift+T)** - Schedule automatic quit
- **Service Pause Settings** - Configure service-based pause
- **Exit (Ctrl+Alt+Q)** - Quit the script

**Note:** The tray menu provides quick access to settings. Use hotkeys for faster access to status and monitoring.

## Understanding Tray Icon States

The tray icon provides visual feedback about script status:

| Icon | State | Meaning |
|------|-------|---------|
| 🖥️ Desktop/PC Icon | Idle/Paused | Script is monitoring for inactivity or manually paused |
| ❌ Red X Icon | Active | Script is performing simulation (mouse moves, key presses, etc.) |

**Icon Behavior:**
- Changes to red X immediately when simulation starts
- Changes back to desktop icon immediately when you move mouse or type
- Changes to desktop icon when manually paused (`Ctrl+Alt+P`)
- Always visible by default (not hidden)

## Troubleshooting

**Can't see tray icon?**
- Press `Ctrl+Shift+H` to toggle visibility
- Check Windows notification area (may be hidden)
- Press `Ctrl+Alt+S` to check status (works without icon)
- Right-click taskbar → Taskbar settings → Select which icons appear

**Not sure if it's running?**
- Press `Ctrl+Alt+S` - if you get a status popup, it's running
- Check tray icon (should be visible by default)
- Check Task Manager for the process
- Press `Ctrl+Alt+M` to open real-time monitor

**Script not responding?**
- Try `Ctrl+Alt+R` to force resume
- Check if it's paused with `Ctrl+Alt+S`
- Check activity log for errors
- Verify service pause settings aren't blocking it

**Tray icon not changing?**
- Icon should change to red X when simulation is active
- Icon should change to desktop icon when paused or when you interact
- If icon doesn't change, check status with `Ctrl+Alt+S`
- Verify script isn't stuck in a paused state

**Real-time monitor not working?**
- Press `Ctrl+Alt+M` to toggle monitor
- If it doesn't open, check if another window is blocking it
- Close and reopen with `Ctrl+Alt+M`

## Quick Reference

**Fastest way to check status:**
1. Look at tray icon (desktop = idle, red X = active)
2. Press `Ctrl+Alt+S` for detailed status
3. Press `Ctrl+Alt+M` for real-time activity monitor

**To verify script is working:**
1. Leave system idle for 50+ seconds
2. Tray icon should change to red X
3. Mouse should start moving automatically
4. Press `Ctrl+Alt+S` to see activity log

---

**Remember**: The script starts with tray icon visible (desktop icon) by default. You can always check status with `Ctrl+Alt+S` or open the real-time monitor with `Ctrl+Alt+M`!

