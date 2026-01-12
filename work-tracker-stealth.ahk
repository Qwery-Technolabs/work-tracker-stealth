#Requires AutoHotkey v2.0
#SingleInstance Force
; Tray icon always visible for owner to see status

; ============================================
; Work Tracker Stealth - AutoHotkey Script
; Developed by Qwery Technolabs
; Copyright (c) 2024 Qwery Technolabs
; ============================================

; Note: In AHK v2, keyboard and mouse hooks are installed automatically when needed
; No need for #InstallKeybdHook or #InstallMouseHook directives

; IMPORTANT: Browser-based keyboard/mouse testers WILL detect this script's activities
; This is normal - browser testers use JavaScript event listeners that detect ALL input events
; To verify script is working, use the activity log (Ctrl+Alt+S) instead of browser testers

; ============================================
; GLOBAL VARIABLES & CONFIGURATION
; ============================================
inactivityThreshold := 50000  ; 50 seconds in milliseconds
inactivityJitter := 1000      ; ±1 second jitter (9-11s range)
lastInputTime := 0
simulationActive := false
pausedByUser := false
scriptActionInProgress := false  ; Flag to track when script is performing actions
scriptActionStartTime := 0  ; Timestamp when script action started
scriptActionEndTime := 0  ; Timestamp when script action ended
actionBufferTime := 3000  ; Buffer time (3 seconds) after script action before checking for human input
lastScriptInputTime := 0  ; Track last input time when script was active
lastMousePos := { x: 0, y: 0 }
lastPositions := []  ; Track last 5 positions to avoid repetition

; Activity log for real-time monitoring (stores last 50 activities)
activityLog := []
maxLogEntries := 50

; Real-time activity tracking
currentActivity := "Idle - Monitoring inactivity"
realtimeMonitorGui := 0
realtimeMonitorActive := false
trayToggleMenuCurrentLabel := ""  ; Tracks current tray toggle menu text

; Service-based pause tracking
pauseServices := []  ; Array of service names to pause when running
serviceCheckEnabled := false  ; Whether to check services

; Mouse click target position (0 = not set, otherwise {x: X, y: Y})
mouseClickTargetPos := 0  ; Target position for multiple left-clicks

; Event enable/disable states (all enabled by default)
eventEnabled := Map(
    "MouseMovement", true,
    "ScrollWheel", true,
    "KeyPresses", true,
    "MouseClicks", true,
    "WindowSwitch", true,
    "HardwareAdjust", true
)

; Event settings defaults (no longer using INI file)

; Function to add activity to log
LogActivity(activityType, details := "") {
    global activityLog, maxLogEntries

    ; Get current time
    currentTime := A_Now
    timeStr := FormatTime(currentTime, "HH:mm:ss")

    ; Create log entry
    logEntry := timeStr . " - " . activityType
    if (details != "") {
        logEntry .= ": " . details
    }

    ; Add to log
    activityLog.Push(logEntry)

    ; Keep only last N entries
    if (activityLog.Length > maxLogEntries) {
        activityLog.RemoveAt(1)
    }
}

; Safe key list (modifier keys only - won't interfere with documents/code or laptop hardware)
; Modifier keys (Ctrl, Alt, Shift) do nothing when pressed alone - completely safe
; These keys won't trigger brightness, volume, or any hardware functions on laptops
; They also won't type characters or modify content in documents/code
keyList := ['Ctrl', 'Alt', 'Shift', 'LControl', 'RControl', 'LAlt', 'RAlt', 'LShift', 'RShift']
lastKey := ""  ; For Markov chain to avoid patterns

; Random mouse movement - no patterns, completely random across screen

; ============================================
; WINDOWS API FUNCTIONS FOR INACTIVITY DETECTION
; ============================================
GetLastInputInfo() {
    ; GetLastInputInfo structure: DWORD cbSize, DWORD dwTime
    lastInputInfo := Buffer(8, 0)
    NumPut("UInt", 8, lastInputInfo, 0)  ; cbSize = 8
    if (DllCall("user32\GetLastInputInfo", "Ptr", lastInputInfo.Ptr)) {
        dwTime := NumGet(lastInputInfo, 4, "UInt")
        return dwTime
    }
    return 0
}

; ============================================
; GAUSSIAN RANDOM NUMBER GENERATOR
; ============================================
RandGaussian(mean, stdDev) {
    ; Box-Muller transform for Gaussian distribution
    static u1 := 0, u2 := 0, z0 := 0, haveSpare := false

    if (haveSpare) {
        haveSpare := false
        return z0 * stdDev + mean
    }

    haveSpare := true
    u1 := Random(0.0, 1.0)
    u2 := Random(0.0, 1.0)
    z0 := Sqrt(-2.0 * Ln(u1)) * Cos(2.0 * 3.14159265359 * u2)
    return z0 * stdDev + mean
}

; Helper function for random integers with Gaussian distribution
RandGaussianInt(mean, stdDev) {
    return Round(RandGaussian(mean, stdDev))
}

; ============================================
; SERVICE CHECKING
; ============================================
; Check if any of the pause services/processes are running
IsPauseServiceRunning() {
    global pauseServices, serviceCheckEnabled

    if (!serviceCheckEnabled || pauseServices.Length == 0) {
        return false
    }

    ; Check each service/process name
    for serviceName in pauseServices {
        ; First try to check as a service
        try {
            ; Use COM to query WMI for service status
            wmi := ComObject("winmgmts:")
            query := "SELECT State FROM Win32_Service WHERE Name='" . serviceName . "'"
            services := wmi.ExecQuery(query)

            for service in services {
                if (service.State == "Running") {
                    return true
                }
            }
        } catch {
            ; Service check failed, try process check
        }

        ; If not found as service, check as process
        try {
            ; Use COM to query WMI for process
            wmi := ComObject("winmgmts:")
            query := "SELECT Name FROM Win32_Process WHERE Name='" . serviceName . "'"
            processes := wmi.ExecQuery(query)

            for process in processes {
                ; Process exists and is running
                return true
            }
        } catch {
            ; Process check also failed, try alternative method
            try {
                ; Try sc.exe for service
                tempFile := A_Temp . "\service_check_" . A_TickCount . ".txt"
                RunWait('cmd.exe /c sc.exe query "' . serviceName . '" > "' . tempFile . '"', , "Hide")

                ; Read the output file
                if (FileExist(tempFile)) {
                    FileRead(&cmdOutput, tempFile)
                    FileDelete(tempFile)

                    ; Check if service is running
                    if (InStr(cmdOutput, "RUNNING")) {
                        return true
                    }
                }
            } catch {
                ; All checks failed, continue to next service/process
                continue
            }
        }
    }

    return false
}

; ============================================
; INACTIVITY DETECTION
; ============================================
CheckInactivity() {
    global lastInputTime, simulationActive, pausedByUser, inactivityThreshold, inactivityJitter
    global serviceCheckEnabled

    ; Don't check if manually paused by user
    if (pausedByUser) {
        return
    }

    ; Check if pause service is running
    if (serviceCheckEnabled && IsPauseServiceRunning()) {
        ; Service is running - pause simulation if active
        if (simulationActive) {
            simulationActive := false
            SetTimer(SimulateHuman, 0)
            LogActivity("Service Check", "Paused - Service is running")
            UpdateTrayIcon()
        }
        return
    }

    ; Get system uptime
    systemUptime := DllCall("kernel32\GetTickCount", "UInt")
    lastInputTick := GetLastInputInfo()

    ; Calculate time since last input
    if (lastInputTick > 0) {
        timeSinceInput := systemUptime - lastInputTick

        ; Apply jitter to threshold (9-11 seconds)
        threshold := inactivityThreshold + Random(-inactivityJitter, inactivityJitter)

        ; If user has been inactive long enough and simulation is not active, start it
        if (timeSinceInput > threshold && !simulationActive) {
            simulationActive := true
            ; Random initial delay before first action (5-15 seconds)
            initialDelay := Random(5000, 15000)
            SetTimer(SimulateHuman, initialDelay)
            LogActivity("Simulation", "Started - Inactivity detected (" . Round(timeSinceInput / 1000) . "s)")
            UpdateTrayIcon()  ; Update to red X icon when active
        }
        ; If simulation is active but user became active (shouldn't happen here, but safety check)
        else if (timeSinceInput <= threshold && simulationActive) {
            ; This case is handled by CheckUserInput, but we keep this for safety
        }
    }
}

; ============================================
; USER INPUT DETECTION & PAUSE
; ============================================
; Track last known input time for comparison
lastKnownInputTime := 0

; Polling-based input detection (more reliable than hooks)
; Only detects REAL human input, completely ignores script's own actions
CheckUserInput() {
    global lastInputTime, simulationActive, pausedByUser, lastKnownInputTime
    global scriptActionInProgress, scriptActionEndTime, actionBufferTime, lastScriptInputTime
    global serviceCheckEnabled

    ; Don't check if manually paused by user
    if (pausedByUser) {
        return
    }

    ; Check if pause service is running
    if (serviceCheckEnabled && IsPauseServiceRunning()) {
        ; Service is running - pause simulation if active
        if (simulationActive) {
            simulationActive := false
            SetTimer(SimulateHuman, 0)
            LogActivity("Service Check", "Paused - Service is running")
            UpdateTrayIcon()
        }
        return
    }

    ; CRITICAL: Completely ignore input detection when script is active
    currentTime := DllCall("kernel32\GetTickCount", "UInt")
    timeSinceActionEnd := currentTime - scriptActionEndTime

    ; Rule 1: If script is performing action RIGHT NOW - ignore ALL input
    if (scriptActionInProgress) {
        ; Script is active - update last known input time but DON'T pause
        currentInputTime := GetLastInputInfo()
        if (currentInputTime > 0) {
            lastScriptInputTime := currentInputTime
            lastKnownInputTime := currentInputTime
        }
        return
    }

    ; Rule 2: If within buffer period after script action - check for user input but be cautious
    ; Get current input time to check if it's user input (for immediate icon update)
    currentInputTime := GetLastInputInfo()
    if (timeSinceActionEnd < actionBufferTime && scriptActionEndTime > 0) {
        ; Still in buffer period - but check if input is different from script's input
        if (currentInputTime > 0 && currentInputTime != lastScriptInputTime && currentInputTime !=
            lastKnownInputTime) {
            ; Input is different from script's input - likely user input
            ; Update icon IMMEDIATELY even during buffer period
            if (simulationActive) {
                simulationActive := false
                UpdateTrayIcon()  ; Update icon immediately
                currentActivity := "⏸️ PAUSED - Real user activity detected"
                SetTimer(SimulateHuman, 0)
                LogActivity("Simulation", "Paused - Real user activity detected (immediate)")
                lastKnownInputTime := currentInputTime
                lastInputTime := currentTime
                return
            }
        }
        ; Update tracking but don't pause yet (still in buffer)
        if (currentInputTime > 0) {
            lastScriptInputTime := currentInputTime
            lastKnownInputTime := currentInputTime
        }
        return
    }

    ; Rule 3: Check for input and update icon IMMEDIATELY if it's clearly user input
    ; Get current input time from Windows API
    currentInputTime := GetLastInputInfo()
    systemUptime := DllCall("kernel32\GetTickCount", "UInt")

    ; Only process if input time changed
    if (currentInputTime != lastKnownInputTime && currentInputTime > 0) {
        ; Check if this input is clearly different from script's last input
        ; If input is different from script input, it's likely user input - update icon immediately
        if (currentInputTime != lastScriptInputTime) {
            ; This input is different from script's input - likely real user activity
            ; Update icon IMMEDIATELY for better responsiveness
            if (simulationActive) {
                UpdateTrayIcon()  ; Update icon immediately when user input detected
            }

            ; Verify this is truly NEW input (not from script)
            ; Input must be significantly different from script's last input AND well after buffer period
            timeSinceAction := systemUptime - scriptActionEndTime

            if (scriptActionEndTime == 0 || timeSinceAction >= actionBufferTime) {
                ; This is REAL human activity detected well after script action - pause simulation
                lastKnownInputTime := currentInputTime
                lastInputTime := systemUptime

                ; If simulation is running, pause it immediately
                if (simulationActive) {
                    simulationActive := false
                    currentActivity := "⏸️ PAUSED - Real user activity detected"
                    SetTimer(SimulateHuman, 0)  ; Stop all scheduled simulation actions
                    LogActivity("Simulation", "Paused - Real user activity detected")
                    UpdateTrayIcon()  ; Ensure icon is updated (already done above, but ensure state is correct)
                }
            } else {
                ; Input is different but still within buffer - update tracking but don't pause yet
                lastKnownInputTime := currentInputTime
            }
        } else {
            ; Input matches script's input - ignore and update tracking
            lastKnownInputTime := currentInputTime
            if (currentInputTime == lastScriptInputTime) {
                ; This input is from script - don't update lastScriptInputTime
            }
        }
    }
}

; Note: CheckUserInput timer is set up in initialization section

; Function to clear script action flag and mark end time
ClearScriptActionFlag() {
    global scriptActionInProgress, scriptActionEndTime, lastScriptInputTime
    scriptActionInProgress := false
    scriptActionEndTime := DllCall("kernel32\GetTickCount", "UInt")
    ; Record the input time when script action ended (to compare against later)
    lastScriptInputTime := GetLastInputInfo()
}

; ============================================
; HUMAN-LIKE MOUSE MOVEMENTS
; ============================================
MouseMoveSmooth(x, y, speed := 1) {
    ; Get current position
    MouseGetPos(&currentX, &currentY)

    ; Calculate distance
    distance := Sqrt((x - currentX) ** 2 + (y - currentY) ** 2)

    ; Use bezier-like curve for smooth, speedy movement
    ; More steps for smoother curve, but faster execution
    steps := Max(8, Round(distance / 8))  ; More steps for smoother movement

    startX := currentX
    startY := currentY

    loop steps {
        ; Bezier interpolation (quadratic) for very smooth curve
        t := A_Index / steps
        bezierT := t * t * (3 - 2 * t)  ; Smooth step function

        newX := startX + (x - startX) * bezierT
        newY := startY + (y - startY) * bezierT

        ; Very speedy movement (speed 1-2 for fast, smooth motion)
        MouseMove(newX, newY, speed)
        Sleep(Random(3, 8))  ; Very fast - reduced from 10-30
    }
}

; Random oval shape movement - creates smooth oval/elliptical paths
; Repeats 10-15 times at bullet speed
OvalShapeMovement(centerX, centerY, radiusX, radiusY, steps := 20) {
    MouseGetPos(&startX, &startY)

    ; Create oval/elliptical path with random orientation
    ; Random rotation angle for oval orientation
    rotationAngle := Random(0, 360) * 3.14159265359 / 180

    ; Repeat oval 10-15 times at bullet speed
    repeatCount := Random(10, 15)

    loop repeatCount {
        ; Each oval loop
        loop steps {
            ; Calculate angle around oval
            angle := (A_Index / steps) * 2 * 3.14159265359

            ; Calculate position on oval (before rotation)
            x := radiusX * Cos(angle)
            y := radiusY * Sin(angle)

            ; Apply rotation
            rotatedX := x * Cos(rotationAngle) - y * Sin(rotationAngle)
            rotatedY := x * Sin(rotationAngle) + y * Cos(rotationAngle)

            ; Translate to center position
            finalX := centerX + rotatedX
            finalY := centerY + rotatedY

            ; Move with bullet speed (extremely fast)
            MouseMove(finalX, finalY, 0)  ; Speed 0 = fastest possible
            Sleep(1)  ; Minimal delay - bullet speed
        }
    }
}

; Long random screen movements - creates random shapes/paths across entire screen
; Movements cover large portions of screen, very speedy, includes random oval shapes
; Always moves from current mouse position (no skipping)
RandomScreenMovement() {
    ; Get screen dimensions
    screenWidth := A_ScreenWidth
    screenHeight := A_ScreenHeight

    ; Get current mouse position (start from where mouse is now)
    MouseGetPos(&currentX, &currentY)

    ; Movement type: 15% small, 25% medium, 30% large waypoints, 30% oval shape
    ; Added oval shape option (30%) - random, not always oval
    movementType := Random(1, 20)

    if (movementType <= 3) {
        ; 15% - Small movement - move to opposite area of screen from current position
        ; Choose destination far from current position
        if (currentX < screenWidth / 2) {
            newX := Random(screenWidth / 2, screenWidth - 10)  ; Move to right side
        } else {
            newX := Random(10, screenWidth / 2)  ; Move to left side
        }
        if (currentY < screenHeight / 2) {
            newY := Random(screenHeight / 2, screenHeight - 10)  ; Move to bottom
        } else {
            newY := Random(10, screenHeight / 2)  ; Move to top
        }
        MouseMoveSmooth(newX, newY, Random(1, 2))

    } else if (movementType <= 8) {
        ; 25% - Medium movement - move to completely different area from current position
        ; Choose destination in opposite quadrant
        if (currentX < screenWidth / 2 && currentY < screenHeight / 2) {
            ; Currently top-left, go to bottom-right
            newX := Random(screenWidth / 2, screenWidth - 10)
            newY := Random(screenHeight / 2, screenHeight - 10)
        } else if (currentX >= screenWidth / 2 && currentY < screenHeight / 2) {
            ; Currently top-right, go to bottom-left
            newX := Random(10, screenWidth / 2)
            newY := Random(screenHeight / 2, screenHeight - 10)
        } else if (currentX < screenWidth / 2 && currentY >= screenHeight / 2) {
            ; Currently bottom-left, go to top-right
            newX := Random(screenWidth / 2, screenWidth - 10)
            newY := Random(10, screenHeight / 2)
        } else {
            ; Currently bottom-right, go to top-left
            newX := Random(10, screenWidth / 2)
            newY := Random(10, screenHeight / 2)
        }
        MouseMoveSmooth(newX, newY, Random(1, 2))

    } else if (movementType <= 14) {
        ; 30% - Large movement with waypoints across entire screen - speedy
        ; Start from current position and visit different quadrants
        waypointCount := Random(3, 6)  ; 3-6 waypoints for longer path

        ; Determine which quadrants to visit (ensure we cover different areas)
        quadrants := [1, 2, 3, 4]
        ; Shuffle quadrants to visit them in random order
        loop quadrants.Length {
            i := Random(1, quadrants.Length)
            j := Random(1, quadrants.Length)
            if (i != j) {
                temp := quadrants[i]
                quadrants[i] := quadrants[j]
                quadrants[j] := temp
            }
        }

        loop waypointCount {
            ; Each waypoint should be in a different quadrant/area
            quadrant := quadrants[Mod(A_Index - 1, quadrants.Length) + 1]
            if (quadrant == 1) {
                ; Top-left quadrant
                waypointX := Random(10, screenWidth / 2)
                waypointY := Random(10, screenHeight / 2)
            } else if (quadrant == 2) {
                ; Top-right quadrant
                waypointX := Random(screenWidth / 2, screenWidth - 10)
                waypointY := Random(10, screenHeight / 2)
            } else if (quadrant == 3) {
                ; Bottom-left quadrant
                waypointX := Random(10, screenWidth / 2)
                waypointY := Random(screenHeight / 2, screenHeight - 10)
            } else {
                ; Bottom-right quadrant
                waypointX := Random(screenWidth / 2, screenWidth - 10)
                waypointY := Random(screenHeight / 2, screenHeight - 10)
            }

            ; Move to waypoint with very smooth, speedy curve
            MouseMoveSmooth(waypointX, waypointY, Random(1, 2))

            ; Very short pause at waypoint (speedy)
            Sleep(Random(20, 50))
        }

        ; Final destination - opposite quadrant from current position
        if (currentX < screenWidth / 2 && currentY < screenHeight / 2) {
            newX := Random(screenWidth / 2, screenWidth - 10)
            newY := Random(screenHeight / 2, screenHeight - 10)
        } else if (currentX >= screenWidth / 2 && currentY < screenHeight / 2) {
            newX := Random(10, screenWidth / 2)
            newY := Random(screenHeight / 2, screenHeight - 10)
        } else if (currentX < screenWidth / 2 && currentY >= screenHeight / 2) {
            newX := Random(screenWidth / 2, screenWidth - 10)
            newY := Random(10, screenHeight / 2)
        } else {
            newX := Random(10, screenWidth / 2)
            newY := Random(10, screenHeight / 2)
        }
        MouseMoveSmooth(newX, newY, Random(1, 2))

    } else {
        ; 30% - Random oval shape movement - speedy
        ; Use current position as starting point, but move to random center for oval
        ; Random center position anywhere on entire screen (including edges)
        centerX := Random(100, screenWidth - 100)
        centerY := Random(100, screenHeight - 100)

        ; First move smoothly to near the oval center (if far away)
        distanceToCenter := Sqrt((centerX - currentX) ** 2 + (centerY - currentY) ** 2)
        if (distanceToCenter > 200) {
            ; Move closer to center first
            approachX := centerX + Random(-50, 50)
            approachY := centerY + Random(-50, 50)
            MouseMoveSmooth(approachX, approachY, Random(1, 2))
            Sleep(Random(50, 100))
        }

        ; Random oval size (large ovals across screen)
        radiusX := Random(150, Min(screenWidth / 3, 400))  ; Horizontal radius
        radiusY := Random(150, Min(screenHeight / 3, 300))  ; Vertical radius

        ; Random number of steps for oval (more steps = smoother)
        steps := Random(15, 25)

        ; Perform speedy oval movement
        OvalShapeMovement(centerX, centerY, radiusX, radiusY, steps)

        ; Update position after oval
        global lastPositions
        MouseGetPos(&finalX, &finalY)
        if (lastPositions.Length >= 5) {
            lastPositions.RemoveAt(1)
        }
        lastPositions.Push({ x: finalX, y: finalY })
        return  ; Exit early for oval movement
    }

    ; Update position history (keep last 5)
    global lastPositions
    if (lastPositions.Length >= 5) {
        lastPositions.RemoveAt(1)
    }
    lastPositions.Push({ x: newX, y: newY })
}

PerformMouseMovement() {
    global lastMousePos, currentActivity

    MouseGetPos(&currentX, &currentY)
    lastMousePos := { x: currentX, y: currentY }

    ; Long random movements across entire screen - creates random shapes/paths
    ; Movements cover large screen areas, very speedy, includes random oval shapes
    ; Movement types: 15% small, 25% medium, 30% waypoints, 30% oval shape
    movementDistance := Random(1, 20)

    if (movementDistance <= 3) {
        ; 15% - Small movement (100-300 pixels) - speedy
        currentActivity := "🖱️ Mouse Movement - Small speedy movement (100-300px)"
    } else if (movementDistance <= 8) {
        ; 25% - Medium movement (300-600 pixels) - speedy
        currentActivity := "🖱️ Mouse Movement - Medium speedy movement (300-600px)"
    } else if (movementDistance <= 14) {
        ; 30% - Large movement with waypoints across entire screen - speedy
        currentActivity := "🖱️ Mouse Movement - Large path with waypoints (speedy)"
    } else {
        ; 30% - Random oval shape movement - repeats 10-15 times at bullet speed
        currentActivity := "🖱️ Mouse Movement - Oval shape (10-15x at bullet speed)"
    }

    ; Perform long random screen movement (includes oval shapes randomly)
    RandomScreenMovement()

    ; Very short pause after movement (speedy)
    Sleep(Random(50, 150))  ; Reduced from 100-300

    ; Log activity
    LogActivity("Mouse Movement", "Long random screen movement (speedy)")

    ; Schedule scroll wheel action after 10 seconds (always after mouse movement)
    ; Always scrolls - if there's overflowing content, it will scroll automatically
    SetTimer(() => PerformScrollAfterMouseMove(), -10000)
}

; ============================================
; BRIGHTNESS & VOLUME CONTROL (LAPTOP HARDWARE)
; ============================================
PerformBrightnessAdjust() {
    ; Natural brightness adjustment - mimics human behavior
    ; Random direction: 50% increase, 50% decrease (humans adjust both ways)
    direction := Random(1, 2)  ; 1 = up, 2 = down

    ; Small increments (1-3 steps) - humans don't jump from min to max
    steps := Random(1, 3)

    ; Use brightness keys (works on most laptops)
    ; Most laptops use Fn+F5/F6 or have dedicated brightness keys
    ; We'll simulate the brightness key presses directly
    if (direction == 1) {
        ; Increase brightness
        loop steps {
            ; Try brightness up key (varies by laptop, but F5 is common)
            ; Some laptops need Fn key, but we'll try direct F5 first
            Send("{F5}")
            Sleep(Random(100, 200))  ; Natural delay between presses
        }
    } else {
        ; Decrease brightness
        loop steps {
            ; Try brightness down key (F6 is common)
            Send("{F6}")
            Sleep(Random(100, 200))
        }
    }

    ; Alternative: Try Windows brightness API if keys don't work
    ; This is a fallback that some systems might support better
    try {
        ; Use PowerShell to adjust brightness (small adjustment)
        brightnessDelta := Random(5, 15)
        if (direction == 1) {
            ; This is a simplified approach - adjust brightness up
            RunWait(
                'powershell.exe -WindowStyle Hidden -Command "$m = Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods; $b = (Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightness).CurrentBrightness; $m.WmiSetBrightness(1, [Math]::Min(100, $b + ' .
                brightnessDelta . '))"', , "Hide")
        } else {
            ; Adjust brightness down
            RunWait(
                'powershell.exe -WindowStyle Hidden -Command "$m = Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods; $b = (Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightness).CurrentBrightness; $m.WmiSetBrightness(1, [Math]::Max(0, $b - ' .
                brightnessDelta . '))"', , "Hide")
        }
    } catch {
        ; If API fails, the key presses above should still work
    }

    ; Natural pause after adjustment (humans don't adjust instantly)
    Sleep(Random(300, 800))

    ; Log activity
    LogActivity("Brightness Adjust", direction == 1 ? "Increase" : "Decrease")
}

PerformVolumeAdjust() {
    ; Natural volume adjustment - mimics human behavior
    ; Random direction: 60% increase, 30% decrease, 10% mute toggle
    action := Random(1, 10)

    if (action <= 6) {
        ; Increase volume (60% - humans often turn up volume)
        steps := Random(1, 4)  ; 1-4 steps up
        loop steps {
            Send("{Volume_Up}")
            Sleep(Random(80, 180))  ; Natural delay
        }
    } else if (action <= 9) {
        ; Decrease volume (30% - less common)
        steps := Random(1, 3)  ; 1-3 steps down
        loop steps {
            Send("{Volume_Down}")
            Sleep(Random(80, 180))
        }
    } else {
        ; Mute toggle (10% - occasional mute/unmute)
        Send("{Volume_Mute}")
        Sleep(Random(500, 1500))  ; Stay muted briefly
        ; 70% chance to unmute after a moment
        if (Random(1, 10) <= 7) {
            Sleep(Random(1000, 3000))
            Send("{Volume_Mute}")  ; Unmute
        }
    }

    ; Natural pause after adjustment
    Sleep(Random(200, 600))

    ; Log activity
    if (action <= 6) {
        LogActivity("Volume Adjust", "Increase")
    } else if (action <= 9) {
        LogActivity("Volume Adjust", "Decrease")
    } else {
        LogActivity("Volume Adjust", "Mute Toggle")
    }
}

PerformHardwareAdjust() {
    global currentActivity
    ; Natural hardware adjustment - brightness and/or volume
    ; 50% chance to adjust brightness, 50% chance for volume
    ; 20% chance to adjust both (humans sometimes adjust multiple things)

    adjustBoth := (Random(1, 10) <= 2)
    if (adjustBoth) {
        currentActivity := "⚙️ Hardware Adjust - Brightness & Volume"
    } else {
        if (Random(1, 2) == 1) {
            currentActivity := "⚙️ Hardware Adjust - Brightness"
        } else {
            currentActivity := "⚙️ Hardware Adjust - Volume"
        }
    }

    if (adjustBoth) {
        ; Adjust both (20% - less common but natural)
        ; Random order: brightness first or volume first
        if (Random(1, 2) == 1) {
            PerformBrightnessAdjust()
            Sleep(Random(500, 1500))  ; Pause between adjustments
            PerformVolumeAdjust()
        } else {
            PerformVolumeAdjust()
            Sleep(Random(500, 1500))
            PerformBrightnessAdjust()
        }
    } else {
        ; Adjust one or the other (80%)
        if (Random(1, 2) == 1) {
            PerformBrightnessAdjust()
        } else {
            PerformVolumeAdjust()
        }
    }
}

; ============================================
; SCROLL WHEEL
; ============================================
; Check if scrolling is possible at current mouse position
; Returns true if the area under mouse is likely scrollable
IsScrollableAtMouse() {
    MouseGetPos(&mouseX, &mouseY)

    ; Get window handle at mouse position
    ; WindowFromPoint takes a POINT structure (x, y as 32-bit values combined into 64-bit)
    point := (mouseY << 16) | (mouseX & 0xFFFF)
    hwnd := DllCall("WindowFromPoint", "Int64", point, "Ptr")

    if (!hwnd || hwnd == 0) {
        return false
    }

    ; Check if window has scrollbars or is scrollable
    ; Get window class name to check if it's a scrollable control
    WinGetClass(&className, "ahk_id " . hwnd)

    ; Common scrollable window classes
    scrollableClasses := ["Edit", "RichEdit", "Scintilla", "ListBox", "ComboBox", "SysListView32",
        "SysTreeView32", "Internet Explorer_Server", "Chrome_WidgetWin_1",
        "MozillaWindowClass", "OperaWindowClass", "ScrollBar"]

    ; Check if it's a known scrollable class
    for class in scrollableClasses {
        if (InStr(className, class)) {
            return true
        }
    }

    ; Check if window has scrollbars using GetWindowLong
    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "UInt")  ; GWL_STYLE
    hasVScroll := (style & 0x00200000) != 0  ; WS_VSCROLL
    hasHScroll := (style & 0x00100000) != 0  ; WS_HSCROLL

    ; If window has scrollbars, it's likely scrollable
    if (hasVScroll || hasHScroll) {
        return true
    }

    ; Default: assume most windows can scroll (browser, text editors, etc.)
    ; We'll attempt scroll anyway - if it doesn't work, nothing happens
    return true
}

; Perform scroll after mouse movement (scheduled 10 seconds after mouse move)
PerformScrollAfterMouseMove() {
    global simulationActive, pausedByUser

    ; Don't scroll if simulation is paused or not active
    if (!simulationActive || pausedByUser) {
        return
    }

    ; Get current mouse position (scroll happens at current location)
    MouseGetPos(&currentX, &currentY)

    ; Always scroll - if there's overflowing content, it will scroll; if not, nothing happens
    ; Random scroll direction: 50% up, 50% down
    scrollDirection := Random(1, 2) == 1 ? "WheelUp" : "WheelDown"

    ; Random scroll amount (4-19 clicks) - more than 3, less than 20
    scrollAmount := Random(4, 19)

    ; Perform scroll at current mouse position
    ; Always send scroll events - they'll work if there's scrollable content
    loop scrollAmount {
        ; Send scroll wheel event (up or down)
        ; This will scroll any overflowing content up or down automatically
        Send("{" . scrollDirection . "}")

        ; Natural delay between scroll clicks (80-200ms)
        ; Humans don't scroll instantly - there's a slight delay
        Sleep(Random(80, 200))
    }

    ; Log activity
    LogActivity("Scroll Wheel", scrollAmount . " " . (scrollDirection == "WheelUp" ? "up" : "down") . " at (" .
    currentX . "," . currentY . ")")
}

; Standalone scroll wheel function for random actions (30% ratio)
PerformScrollWheel() {
    global simulationActive, pausedByUser

    ; Don't scroll if simulation is paused or not active
    if (!simulationActive || pausedByUser) {
        return
    }

    ; Get current mouse position (scroll happens at current location)
    MouseGetPos(&currentX, &currentY)

    ; Always scroll - if there's overflowing content, it will scroll; if not, nothing happens
    ; Random scroll direction: 50% up, 50% down
    scrollDirection := Random(1, 2) == 1 ? "WheelUp" : "WheelDown"

    ; Random scroll amount (4-19 clicks) - more than 3, less than 20
    scrollAmount := Random(4, 19)

    ; Perform scroll at current mouse position
    ; Always send scroll events - they'll work if there's scrollable content
    loop scrollAmount {
        ; Send scroll wheel event (up or down)
        ; This will scroll any overflowing content up or down automatically
        Send("{" . scrollDirection . "}")

        ; Natural delay between scroll clicks (80-200ms)
        ; Humans don't scroll instantly - there's a slight delay
        Sleep(Random(80, 200))
    }

    ; Log activity
    LogActivity("Scroll Wheel", scrollAmount . " " . (scrollDirection == "WheelUp" ? "up" : "down") . " at (" .
    currentX . "," . currentY . ")")
}

; ============================================
; MOUSE CLICKS (MULTIPLE LEFT-CLICKS)
; ============================================
; --- Screen/monitor helpers (fixes multi-monitor + coordinate confusion) ---
GetCursorPosScreen(&x, &y) {
    point := Buffer(8, 0)  ; POINT (x,y) as 32-bit integers
    DllCall("GetCursorPos", "Ptr", point)
    x := NumGet(point, 0, "Int")
    y := NumGet(point, 4, "Int")
}

; Returns monitor rect for a point (supports multi-monitor + negative virtual coords)
; Outputs: left, top, right, bottom, monIndex
GetMonitorRectFromPoint(x, y, &left, &top, &right, &bottom, &monIndex := 0) {
    monCount := MonitorGetCount()
    Loop monCount {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if (x >= l && x <= r && y >= t && y <= b) {
            left := l, top := t, right := r, bottom := b, monIndex := A_Index
            return true
        }
    }

    ; Fallback: primary monitor
    primary := MonitorGetPrimary()
    MonitorGet(primary, &left, &top, &right, &bottom)
    monIndex := primary
    return false
}

ClampPointToMonitor(x, y, &outX, &outY, padding := 0) {
    GetMonitorRectFromPoint(x, y, &l, &t, &r, &b, &monIdx)
    outX := Min(Max(x, l + padding), r - padding)
    outY := Min(Max(y, t + padding), b - padding)
}

ShowAlwaysOnTopMessageForWindow(ownerWinTitle, message, title) {
    ownerHwnd := 0
    if (ownerWinTitle != "") {
        try ownerHwnd := WinExist(ownerWinTitle)
    }
    return ShowOwnedPopup(ownerHwnd, message, title)
}

; Owned popup: stays above owner (fixes "popup behind always-on-top window")
; Also clamps position so the window (including close button) is never cut off-screen.
ShowOwnedPopup(ownerHwnd, message, title) {
    msgBoxWidth := 420
    msgBoxHeight := 170
    msgX := ""
    msgY := ""

    try {
        if (ownerHwnd && WinExist("ahk_id " . ownerHwnd)) {
            WinGetPos(&ownerX, &ownerY, &ownerW, &ownerH, "ahk_id " . ownerHwnd)

            ; Place centered above owner (fallback to below if not enough space)
            candidateX := ownerX + Round((ownerW - msgBoxWidth) / 2)
            candidateY := ownerY - msgBoxHeight - 10

            ; Clamp to the monitor containing the owner's center
            centerX := ownerX + Round(ownerW / 2)
            centerY := ownerY + Round(ownerH / 2)
            GetMonitorRectFromPoint(centerX, centerY, &l, &t, &r, &b, &monIdx)

            maxX := r - msgBoxWidth
            maxY := b - msgBoxHeight

            if (candidateY < t) {
                candidateY := ownerY + ownerH + 10  ; show below owner if above would be off-screen
            }

            msgX := Min(Max(candidateX, l), maxX)
            msgY := Min(Max(candidateY, t), maxY)
        }
    } catch {
        ; ignore and fall back to centered
    }

    try {
        opts := "+AlwaysOnTop -MaximizeBox -MinimizeBox"
        if (ownerHwnd) {
            opts .= " +Owner" . ownerHwnd
        }

        msgGui := Gui(opts, title)
        msgGui.SetFont("s10", "Segoe UI")
        msgGui.Add("Text", "x10 y10 w400", message)
        okBtn := msgGui.Add("Button", "x170 y120 w80 h30 Default", "OK")
        okBtn.OnEvent("Click", (*) => msgGui.Destroy())
        msgGui.OnEvent("Escape", (*) => msgGui.Destroy())

        if (msgX != "" && msgY != "") {
            msgGui.Show("x" . msgX . " y" . msgY . " w" . msgBoxWidth . " h" . msgBoxHeight)
        } else {
            msgGui.Show("w" . msgBoxWidth . " h" . msgBoxHeight)
        }

        WinActivate("ahk_id " . msgGui.Hwnd)
        WinWaitClose("ahk_id " . msgGui.Hwnd)
        return true
    } catch {
        MsgBox(message, title, "OK")
        return false
    }
}

; Check if a screen point is in a safe "content area" on the monitor containing it.
IsInContentArea(mouseX, mouseY) {
    GetMonitorRectFromPoint(mouseX, mouseY, &l, &t, &r, &b, &monIdx)

    ; Margins to avoid taskbar/menu edges (per-monitor)
    topMargin := 50
    bottomMargin := 60
    leftMargin := 5
    rightMargin := 5

    if (mouseY < (t + topMargin) || mouseY > (b - bottomMargin)) {
        return false
    }
    if (mouseX < (l + leftMargin) || mouseX > (r - rightMargin)) {
        return false
    }
    return true
}

; Pick a mouse click target position using global screen coordinates.
; Uses only ToolTip (no blocking popup), so clicks are captured on the actual target window.
PickMouseClickTargetPosition(sourceLabel := "", ownerWinTitle := "") {
    global mouseClickTargetPos

    ; Avoid capturing the click that triggered the picker button/hotkey
    Sleep(250)
    while GetKeyState("LButton", "P") {
        Sleep(10)
    }

    lastDown := false
    Loop {
        ; Cancel
        if GetKeyState("Esc", "P") {
            ToolTip()
            return false
        }

        GetCursorPosScreen(&x, &y)
        GetMonitorRectFromPoint(x, y, &l, &t, &r, &b, &monIdx)
        relX := x - l
        relY := y - t

        ; Display live position (absolute + monitor-relative)
        ToolTip(
            "Set Mouse Click Target Position`n" .
            "Move mouse to the desired spot and LEFT-CLICK to set.`n" .
            "Press ESC to cancel.`n`n" .
            "Monitor: " . monIdx . "`n" .
            "Screen: (" . x . ", " . y . ")`n" .
            "Monitor-relative: (" . relX . ", " . relY . ")"
        )

        isDown := GetKeyState("LButton", "P")
        if (isDown && !lastDown) {
            ; Capture on first down
            GetCursorPosScreen(&finalX, &finalY)

            ; Always allow edge positions. Only clamp to the monitor bounds to avoid out-of-range values.
            ClampPointToMonitor(finalX, finalY, &finalX, &finalY, 0)
            mouseClickTargetPos := { x: finalX, y: finalY }
            ToolTip()
            UpdateSettingsWindowTargetPosition()
            LogActivity("Mouse Click Target", "Set to (" . finalX . ", " . finalY . ")" . (sourceLabel != "" ? " - " . sourceLabel : ""))
            ; If ownerWinTitle is provided, treat it as owner for stacking; otherwise show standalone.
            ownerHwnd := 0
            if (ownerWinTitle != "") {
                try ownerHwnd := WinExist(ownerWinTitle)
            }
            ShowOwnedPopup(ownerHwnd, "✓ Mouse click target position set!`n`nPosition: (" . finalX . ", " . finalY . ")", "Target Position Set")
            return true
        }

        lastDown := isDown
        Sleep(25)
    }
}

; Perform multiple left-clicks (e.g., 10 clicks within 1-3 seconds)
; Only clicks if mouse is in content area (not taskbar or menu bar)
; Uses pre-selected target position if set, otherwise uses current mouse position
PerformMouseClicks() {
    global simulationActive, pausedByUser, currentActivity, mouseClickTargetPos

    ; Don't click if simulation is paused or not active
    if (!simulationActive || pausedByUser) {
        return
    }

    ; Determine target position
    targetX := 0
    targetY := 0
    useTargetPos := false

    ; Check if user has set a target position
    if (mouseClickTargetPos != 0 && mouseClickTargetPos.HasProp("x") && mouseClickTargetPos.HasProp("y")) {
        ; Use pre-selected target position
        targetX := mouseClickTargetPos.x
        targetY := mouseClickTargetPos.y
        useTargetPos := true
        ; Always allow the user-chosen target. Clamp to monitor bounds for safety.
        ClampPointToMonitor(targetX, targetY, &targetX, &targetY, 0)
    }

    ; If no target position set or invalid, use current mouse position
    if (!useTargetPos) {
        MouseGetPos(&targetX, &targetY)
    }

    ; If using current position and it's not in a safe content area, move to a safe position.
    ; If using the user-defined target, we do NOT override it.
    if (!useTargetPos && !IsInContentArea(targetX, targetY)) {
        ; Target is not in content area - move to a safe content area position on the current monitor
        GetCursorPosScreen(&curX, &curY)
        GetMonitorRectFromPoint(curX, curY, &l, &t, &r, &b, &monIdx)

        ; Pick a safe-ish point inside margins
        topMargin := 60
        bottomMargin := 80
        leftMargin := 20
        rightMargin := 20
        targetX := Random(l + leftMargin, r - rightMargin)
        targetY := Random(t + topMargin, b - bottomMargin)

        ; Move smoothly to safe position
        MouseMoveSmooth(targetX, targetY, Random(1, 2))
        Sleep(Random(100, 200))

        ; Update position after movement
        MouseGetPos(&targetX, &targetY)

        ; Double-check we're in content area after movement
        if (!IsInContentArea(targetX, targetY)) {
            ; Still not in content area - skip clicking
            LogActivity("Mouse Click", "Skipped - mouse not in content area")
            return
        }
    } else if (useTargetPos) {
        ; Target position is set and valid - move to it first
        MouseMoveSmooth(targetX, targetY, Random(1, 2))
        Sleep(Random(100, 200))
    }

    ; Store final position for logging
    currentX := targetX
    currentY := targetY

    ; Mouse is in content area - proceed with clicks
    ; Random number of clicks (8-12 clicks, with 10 as typical)
    clickCount := Random(8, 12)

    ; Total duration should be 1-3 seconds
    totalDuration := Random(1000, 3000)

    ; Calculate delay between clicks to fit within total duration
    delayBetweenClicks := Round(totalDuration / clickCount)

    ; Ensure minimum delay between clicks (at least 50ms for natural feel)
    if (delayBetweenClicks < 50) {
        delayBetweenClicks := 50
        ; Recalculate total duration if needed
        totalDuration := clickCount * delayBetweenClicks
    }

    ; Perform clicks
    currentActivity := "🖱️ Mouse Click - " . clickCount . " left-clicks in content area"

    loop clickCount {
        ; Perform left-click at current position
        Click()

        ; Natural delay between clicks (with small random variation)
        if (A_Index < clickCount) {
            ; Add small random variation to delay (±10ms)
            actualDelay := delayBetweenClicks + Random(-10, 10)
            if (actualDelay < 30) {
                actualDelay := 30  ; Minimum 30ms delay
            }
            Sleep(actualDelay)
        }
    }

    ; Log activity
    positionSource := useTargetPos ? " (target position)" : " (current position)"
    LogActivity("Mouse Click", clickCount . " left-clicks at (" . currentX . "," . currentY . ")" . positionSource .
        " in " . Round(totalDuration) . "ms")
}

; ============================================
; WINDOW SWITCHING (ALT+TAB)
; ============================================
PerformWindowSwitch() {
    global currentActivity
    ; Simulate Alt+Tab window switching (very human-like behavior)
    ; Random number of tab presses (1-3) to switch between windows
    tabCount := Random(1, 3)
    currentActivity := "🪟 Window Switch - Alt+Tab (" . tabCount . " tabs)"

    ; Hold Alt key
    Send("{Alt down}")
    Sleep(Random(50, 100))  ; Small delay before first tab

    ; Press Tab multiple times
    loop tabCount {
        Send("{Tab}")
        Sleep(Random(150, 300))  ; Natural delay between tabs
    }

    ; Release Alt to switch to the selected window
    Sleep(Random(100, 200))
    Send("{Alt up}")

    ; Stay on switched window for a bit (2-5 seconds)
    Sleep(Random(2000, 5000))

    ; 60% chance to switch back (simulate checking another window then returning)
    if (Random(1, 10) <= 6) {
        Send("{Alt down}")
        Sleep(Random(50, 100))
        Send("{Tab}")
        Sleep(Random(100, 200))
        Send("{Alt up}")
    }

    ; Log activity
    LogActivity("Window Switch", tabCount . " tabs")
}

; ============================================
; RANDOM KEY PRESSES
; ============================================
PerformKeyPresses() {
    global keyList, lastKey, currentActivity

    ; Random sequence length (2-5 presses)
    seqLen := Random(2, 5)
    currentActivity := "⌨️ Key Press - Sending " . seqLen . " modifier keys"

    loop seqLen {
        ; Markov chain: avoid adjacent keys
        if (lastKey != "" && Random(1, 10) <= 7) {
            ; Bias towards non-adjacent keys
            filteredKeys := []
            for key in keyList {
                if (key != lastKey) {
                    filteredKeys.Push(key)
                }
            }
            if (filteredKeys.Length > 0) {
                key := filteredKeys[Random(1, filteredKeys.Length)]
            } else {
                key := keyList[Random(1, keyList.Length)]
            }
        } else {
            key := keyList[Random(1, keyList.Length)]
        }

        lastKey := key

        ; Send modifier key (Ctrl, Alt, Shift) - completely safe, does nothing when pressed alone
        ; These keys won't trigger laptop hardware functions (brightness, volume, etc.)
        ; They also won't type characters or modify content in documents/code
        if (Random(1, 10) == 1) {
            ; 10% chance for key hold (simulates natural key press)
            Send("{" . key . " down}")
            Sleep(Random(200, 500))
            Send("{" . key . " up}")
        } else {
            ; Normal modifier key press (press and release quickly)
            Send("{" . key . " down}")
            Sleep(Random(50, 150))  ; Short hold for modifier keys
            Send("{" . key . " up}")
        }

        ; Random delay between keys (100-300ms)
        Sleep(Random(100, 300))

        ; 5% chance for micro mouse movement during typing
        if (Random(1, 20) == 1) {
            MouseGetPos(&x, &y)
            MouseMove(x + Random(-2, 2), y + Random(-2, 2), 1)
        }
    }

    ; Add Scroll Lock key press (2 times) - safe key that doesn't interfere with work
    ; 30% chance to press Scroll Lock after modifier keys
    if (Random(1, 10) <= 3) {
        ; Press Scroll Lock twice with natural delay
        Send("{ScrollLock}")
        Sleep(Random(100, 200))  ; Natural delay between presses
        Send("{ScrollLock}")
        LogActivity("Key Press", "Scroll Lock pressed 2 times")
    }

    ; Log activity after sequence completes
    LogActivity("Key Press", seqLen . " modifier keys")
}

; ============================================
; MAIN SIMULATION LOOP
; ============================================
SimulateHuman() {
    global simulationActive, pausedByUser, scriptActionInProgress
    global scriptActionStartTime, scriptActionEndTime, eventEnabled

    if (!simulationActive || pausedByUser) {
        return
    }

    ; Mark script action start time (for distinguishing script vs human input)
    scriptActionStartTime := DllCall("kernel32\GetTickCount", "UInt")

    ; Set flag to indicate script is performing actions (prevents self-pause)
    scriptActionInProgress := true

    ; Build list of enabled events with their weight ranges
    ; Original distribution: 25% mouse, 25% scroll, 20% keys, 15% mouse clicks, 10% window switch, 5% hardware
    enabledEvents := []
    if (eventEnabled["MouseMovement"]) {
        enabledEvents.Push({ name: "MouseMovement", min: 1, max: 25 })
    }
    if (eventEnabled["ScrollWheel"]) {
        enabledEvents.Push({ name: "ScrollWheel", min: 26, max: 50 })
    }
    if (eventEnabled["KeyPresses"]) {
        enabledEvents.Push({ name: "KeyPresses", min: 51, max: 70 })
    }
    if (eventEnabled["MouseClicks"]) {
        enabledEvents.Push({ name: "MouseClicks", min: 71, max: 85 })
    }
    if (eventEnabled["WindowSwitch"]) {
        enabledEvents.Push({ name: "WindowSwitch", min: 86, max: 95 })
    }
    if (eventEnabled["HardwareAdjust"]) {
        enabledEvents.Push({ name: "HardwareAdjust", min: 96, max: 100 })
    }

    ; If no events are enabled, skip this action
    if (enabledEvents.Length == 0) {
        scriptActionInProgress := false
        SetTimer(SimulateHuman, Random(5000, 10000))
        return
    }

    ; Calculate total weight and select from enabled events
    totalWeight := 0
    for event in enabledEvents {
        totalWeight += (event.max - event.min + 1)
    }

    ; Select random value within total weight
    randAction := Random(1, totalWeight)

    ; Find which event this corresponds to
    cumulativeWeight := 0
    selectedEvent := ""
    for event in enabledEvents {
        eventWeight := (event.max - event.min + 1)
        if (randAction <= cumulativeWeight + eventWeight) {
            selectedEvent := event.name
            ; Calculate original randAction value for compatibility with existing code
            randAction := event.min + (randAction - cumulativeWeight - 1)
            break
        }
        cumulativeWeight += eventWeight
    }

    ; Log simulation start
    LogActivity("Simulation", "Action triggered")

    ; Execute selected event
    if (selectedEvent == "MouseMovement") {
        ; Mouse movement (25%) - scroll will trigger automatically 10 seconds after this
        currentActivity := "🖱️ Mouse Movement - Random paths & oval shapes"
        PerformMouseMovement()
        currentActivity := "✅ Mouse Movement Complete (scroll scheduled in 10s)"
    } else if (selectedEvent == "ScrollWheel") {
        ; Scroll wheel (25%) - standalone scroll action
        currentActivity := "🖱️ Mouse Scroll - Random scroll up/down"
        PerformScrollWheel()
        currentActivity := "✅ Scroll Complete"
    } else if (selectedEvent == "KeyPresses") {
        ; Key presses (20%)
        currentActivity := "⌨️ Key Press - Sending modifier keys"
        PerformKeyPresses()
        currentActivity := "✅ Key Press Complete"
    } else if (selectedEvent == "MouseClicks") {
        ; Mouse clicks (15%) - multiple left-clicks in content area
        currentActivity := "🖱️ Mouse Click - Multiple left-clicks in content area"
        PerformMouseClicks()
        currentActivity := "✅ Mouse Click Complete"
    } else if (selectedEvent == "WindowSwitch") {
        ; Window switching with Alt+Tab (10%)
        currentActivity := "🪟 Window Switch - Switching between windows (Alt+Tab)"
        PerformWindowSwitch()
        currentActivity := "✅ Window Switch Complete"
    } else if (selectedEvent == "HardwareAdjust") {
        ; Hardware adjustment - brightness/volume (5% - natural laptop usage)
        currentActivity := "⚙️ Hardware Adjust - Adjusting brightness/volume"
        PerformHardwareAdjust()
        currentActivity := "✅ Hardware Adjust Complete"
    }

    ; Mark script action end time and clear flag after action completes
    ; This allows input detection to distinguish between script actions and human input
    ; Calculate delay based on action type to ensure action is fully complete
    if (randAction <= 25) {
        ; Mouse movement - speedy, clear after 500ms (longer for oval shapes that repeat 10-15x)
        ; Oval shapes take longer due to 10-15 repetitions
        SetTimer(ClearScriptActionFlag, -500)
    } else if (randAction <= 50) {
        ; Scroll wheel - quick, clear after 200ms
        SetTimer(ClearScriptActionFlag, -200)
    } else if (randAction <= 70) {
        ; Key presses - quick, clear after 300ms
        SetTimer(ClearScriptActionFlag, -300)
    } else if (randAction <= 85) {
        ; Mouse clicks - takes 1-3 seconds, clear after 3.5 seconds
        SetTimer(ClearScriptActionFlag, -3500)
    } else if (randAction <= 95) {
        ; Window switch - takes a few seconds, clear after 3 seconds
        SetTimer(ClearScriptActionFlag, -3000)
    } else {
        ; Hardware adjust - quick, clear after 200ms
        SetTimer(ClearScriptActionFlag, -200)
    }

    ; Schedule next action - reduced to 5-10 seconds (random but less than before)
    ; All actions now happen more frequently for better activity simulation
    if (randAction <= 25) {
        ; Mouse movement - every 5-10 seconds (speedy)
        nextDelay := Random(5000, 10000)
    } else if (randAction <= 50) {
        ; Scroll wheel - every 5-10 seconds (speedy)
        nextDelay := Random(5000, 10000)
    } else if (randAction <= 70) {
        ; Key presses - every 5-10 seconds (reduced from 8-15)
        nextDelay := Random(5000, 10000)
    } else if (randAction <= 85) {
        ; Mouse clicks - every 5-10 seconds
        nextDelay := Random(5000, 10000)
    } else if (randAction <= 95) {
        ; Window switch - every 5-10 seconds (reduced, more frequent)
        nextDelay := Random(5000, 10000)
    } else {
        ; Hardware adjust - every 5-10 seconds (reduced)
        nextDelay := Random(5000, 10000)
    }
    SetTimer(SimulateHuman, nextDelay)
}

; ============================================
; HOTKEYS
; ============================================
^!p:: {  ; Ctrl+Alt+P: Toggle Pause
    TogglePauseState("Hotkey")
}

^!r:: {  ; Ctrl+Alt+R: Force Resume
    global simulationActive, pausedByUser
    pausedByUser := false
    simulationActive := true
    SetTimer(SimulateHuman, Random(5000, 15000))
    UpdateTrayIcon()  ; Update to red X icon when active
}

^!q:: {  ; Ctrl+Alt+Q: Quit
    ExitApp()
}

^+h:: {  ; Ctrl+Shift+H: Toggle Tray Icon
    try {
        if (A_IconHidden) {
            TraySetIcon()  ; Show icon
            ; Tray icon shown
        } else {
            TraySetIcon(, , 0)  ; Hide icon
            ; Tray icon hidden
        }
    } catch {
        ; If TraySetIcon fails, just show a message
        ; Toggle failed
    }
}

^!s:: {  ; Ctrl+Alt+S: Show Status (Owner Check)
    global simulationActive, pausedByUser, lastInputTime, inactivityThreshold
    ShowScriptStatus()
}

^!m:: {  ; Ctrl+Alt+M: Real-time Activity Monitor
    ToggleRealtimeMonitor()
}

^!+c:: {  ; Ctrl+Alt+Shift+C: Set Mouse Click Target Position
    PickMouseClickTargetPosition("Hotkey")
}

; Global reference to settings GUI controls for updating
globalSettingsGuiControls := 0
globalEventSettingsGuiControls := 0

; Function to update target position display in settings windows
UpdateSettingsWindowTargetPosition() {
    global globalSettingsGuiControls, globalEventSettingsGuiControls, mouseClickTargetPos

    ; Update General Settings window if open
    if (globalSettingsGuiControls != 0) {
        try {
            controls := globalSettingsGuiControls
            if (mouseClickTargetPos != 0 && mouseClickTargetPos.HasProp("x") && mouseClickTargetPos.HasProp("y")) {
                ; Update to show position
                controls.clickTargetText.Text := "Position: (" . mouseClickTargetPos.x . ", " . mouseClickTargetPos.y . ")"
                controls.clickTargetText.SetFont("cBlack")
                controls.clearTargetBtn.Enabled := true
            } else {
                ; Update to show no position
                controls.clickTargetText.Text := "No target position set"
                controls.clickTargetText.SetFont("cGray")
                controls.clearTargetBtn.Enabled := false
            }
        } catch {
            ; If update fails, that's okay
        }
    }

    ; Update Event Settings window if open
    if (globalEventSettingsGuiControls != 0) {
        try {
            controls := globalEventSettingsGuiControls
            if (mouseClickTargetPos != 0 && mouseClickTargetPos.HasProp("x") && mouseClickTargetPos.HasProp("y")) {
                ; Update to show position
                controls.clickTargetText.Text := "Position: (" . mouseClickTargetPos.x . ", " . mouseClickTargetPos.y . ")"
                controls.clickTargetText.SetFont("cBlack")
                controls.clearTargetBtn.Enabled := true
            } else {
                ; Update to show no position
                controls.clickTargetText.Text := "No target position set"
                controls.clickTargetText.SetFont("cGray")
                controls.clearTargetBtn.Enabled := false
            }
        } catch {
            ; If update fails, that's okay
        }
    }
}

; Function to set target position from GUI button - shows live position picker
SetTargetPositionFromGUI(clickTargetText, setTargetBtn, clearTargetBtn, settingsGui, *) {
    PickMouseClickTargetPosition("GUI", "Event Settings")
}

; Function to update position display in picker window
UpdatePickerPosition(posTextCtrl, statusTextCtrl, positionCaptured := false) {
    ; Check if controls still exist (window might be closed)
    try {
        ; If position already captured, don't update
        if (positionCaptured) {
            return
        }

        ; Get mouse position in screen coordinates
        MouseGetPos(&currentX, &currentY)
        
        ; Verify coordinates are screen coordinates (not window-relative)
        screenWidth := A_ScreenWidth
        screenHeight := A_ScreenHeight
        
        ; If coordinates seem wrong, use DllCall as fallback
        if (currentX < 0 || currentY < 0 || currentX > screenWidth * 2 || currentY > screenHeight * 2) {
            point := Buffer(8, 0)  ; POINT structure
            DllCall("GetCursorPos", "Ptr", point)
            currentX := NumGet(point, 0, "Int")
            currentY := NumGet(point, 4, "Int")
        }

        ; Update position text
        posTextCtrl.Text := "Position: (" . currentX . ", " . currentY . ")"

        ; Update status based on position validity
        screenWidth := A_ScreenWidth
        screenHeight := A_ScreenHeight
        topMarginLenient := 20
        bottomMarginLenient := 30
        leftMarginLenient := 1
        rightMarginLenient := 1

        isInLenientArea := (currentY >= topMarginLenient && currentY <= (screenHeight - bottomMarginLenient)
        && currentX >= leftMarginLenient && currentX <= (screenWidth - rightMarginLenient))

        if (isInLenientArea) {
            statusTextCtrl.Text := "✓ Valid position - Click anywhere to select"
            statusTextCtrl.SetFont("cGreen")
        } else {
            statusTextCtrl.Text := "⚠ Position too close to edges"
            statusTextCtrl.SetFont("cRed")
        }
    } catch {
        ; Window closed or controls invalid - timer will be stopped
    }
}

TogglePauseState(trigger := "User") {
    global simulationActive, pausedByUser, currentActivity

    pausedByUser := !pausedByUser

    if (pausedByUser) {
        simulationActive := false
        SetTimer(SimulateHuman, 0)
        currentActivity := "⏸️ PAUSED - Manual toggle active"
        LogActivity(trigger, "Paused simulation")
    } else {
        currentActivity := "⏳ Idle - Monitoring for inactivity (10s threshold)"
        LogActivity(trigger, "Resumed simulation")
    }

    UpdateTrayIcon()
}

; ============================================
; NEW FEATURE: SCHEDULED AUTO-QUIT
; ============================================
; Global variable to track scheduled quit time (0 = not scheduled)
scheduledQuitTime := 0

; ============================================
; NEW FEATURE: GENERAL SETTINGS
; ============================================
; Function to load event settings (using defaults defined in script)
LoadEventSettings() {
    global eventEnabled

    ; Default: all events enabled
    defaultEvents := Map(
        "MouseMovement", true,
        "ScrollWheel", true,
        "KeyPresses", true,
        "MouseClicks", true,
        "WindowSwitch", true,
        "HardwareAdjust", true
    )

    ; Use defaults
    eventEnabled := defaultEvents.Clone()
}

; Function to save event settings (no longer saving to INI file, settings are runtime-only)
SaveEventSettings() {
    ; Settings are now runtime-only, no persistence needed
    ; This function is kept for compatibility but does nothing
}

; Function to show event settings dialog
ShowEventSettings() {
    global eventEnabled, mouseClickTargetPos
    
    ; Create GUI for event settings
    eventGui := Gui("+AlwaysOnTop -Resize", "Event Settings")
    eventGui.SetFont("s10", "Segoe UI")
    
    ; Title
    titleLabel := eventGui.Add("Text", "x20 y15 w430", "Event Settings")
    descLabel := eventGui.Add("Text", "x20 y35 w430 cGray",
        "Enable/disable simulation events. Settings apply immediately.")
    
    ; Tab control (group events by device type)
    tab := eventGui.Add("Tab3", "x20 y60 w430 h270", ["Mouse", "Keyboard", "Other"])
    
    eventCheckboxes := Map()
    
    ; ----------------------------
    ; Mouse tab
    ; ----------------------------
    tab.UseTab(1)
    eventCheckboxes["MouseMovement"] := eventGui.Add("Checkbox", "x40 y100 w250", "Mouse Movement")
    eventCheckboxes["ScrollWheel"] := eventGui.Add("Checkbox", "x40 y125 w250", "Scroll Wheel")
    eventCheckboxes["MouseClicks"] := eventGui.Add("Checkbox", "x40 y150 w250", "Mouse Clicks")
    
    ; Mouse Click Target Position (mouse-only setting)
    clickTargetLabel1 := eventGui.Add("Text", "x40 y185 w380", "Mouse Click Target Position:")
    clickTargetLabel2 := eventGui.Add("Text", "x40 y200 w380 cGray",
        "Used for multiple left-click actions (optional)")
    if (mouseClickTargetPos != 0 && mouseClickTargetPos.HasProp("x") && mouseClickTargetPos.HasProp("y")) {
        clickTargetText := eventGui.Add("Text", "x40 y223 w200", "Position: (" . mouseClickTargetPos.x . ", " .
            mouseClickTargetPos.y . ")")
        setTargetBtn := eventGui.Add("Button", "x250 y218 w90 h25", "Set Target")
        clearTargetBtn := eventGui.Add("Button", "x345 y218 w90 h25", "Clear")
    } else {
        clickTargetText := eventGui.Add("Text", "x40 y223 w200 cGray", "No target position set")
        setTargetBtn := eventGui.Add("Button", "x250 y218 w90 h25", "Set Target")
        clearTargetBtn := eventGui.Add("Button", "x345 y218 w90 h25 Disabled", "Clear")
    }
    
    ; ----------------------------
    ; Keyboard tab
    ; ----------------------------
    tab.UseTab(2)
    eventCheckboxes["KeyPresses"] := eventGui.Add("Checkbox", "x40 y100 w250", "Key Presses")
    
    ; ----------------------------
    ; Other tab
    ; ----------------------------
    tab.UseTab(3)
    eventCheckboxes["WindowSwitch"] := eventGui.Add("Checkbox", "x40 y100 w320", "Window Switch (Alt+Tab)")
    eventCheckboxes["HardwareAdjust"] := eventGui.Add("Checkbox", "x40 y125 w320", "Hardware Adjust")
    
    ; End tabbed section
    tab.UseTab()
    
    ; Set checkbox values from current settings
    for eventName, checkbox in eventCheckboxes {
        checkbox.Value := eventEnabled[eventName] ? 1 : 0
    }

    ; Info text
    noteText := eventGui.Add("Text", "x20 y340 w430 cGray",
        "Tip: Use ESC to cancel target selection while the tooltip picker is active.")
    
    ; Buttons
    saveBtn := eventGui.Add("Button", "x140 y365 w100 h30 Default", "Save")
    cancelBtn := eventGui.Add("Button", "x250 y365 w100 h30", "Close")
    
    ; Store controls globally for updating
    global globalEventSettingsGuiControls
    globalEventSettingsGuiControls := { clickTargetText: clickTargetText, setTargetBtn: setTargetBtn, clearTargetBtn: clearTargetBtn }

    ; Clean up global reference when window closes
    eventGui.OnEvent("Close", (*) => (
        globalEventSettingsGuiControls := 0
    ))

    ; Button handlers
    saveBtn.OnEvent("Click", SaveEventSettingsHandler.Bind(eventCheckboxes, eventGui))
    cancelBtn.OnEvent("Click", (*) => (globalEventSettingsGuiControls := 0, eventGui.Destroy()))
    setTargetBtn.OnEvent("Click", SetTargetPositionFromGUI.Bind(clickTargetText, setTargetBtn, clearTargetBtn,
        eventGui))
    clearTargetBtn.OnEvent("Click", ClearClickTargetHandler.Bind(clickTargetText, setTargetBtn, clearTargetBtn,
        eventGui))
    
    ; Show window
    eventGui.Show("w480 h410")
}

; Function to save event settings
SaveEventSettingsHandler(eventCheckboxes, eventGui, *) {
    global eventEnabled
    
    ; Save event states from checkboxes
    for eventName, checkbox in eventCheckboxes {
        eventEnabled[eventName] := (checkbox.Value == 1)
    }
    
    ; Log changes
    LogActivity("Event Settings", "Event settings updated")
    
    ; Close window
    eventGui.Destroy()
}

; Custom hotkey: Ctrl+Alt+Shift+S (unused by browsers, Windows, or editors)
^!+s:: {  ; Ctrl+Alt+Shift+S: Open General Settings
    ShowGeneralSettings()
}

; Function to show general settings dialog
ShowGeneralSettings() {
    global inactivityThreshold, inactivityJitter, actionBufferTime, mouseClickTargetPos

    ; Store original default values from global variables (these are the script defaults)
    ; These values come from the GLOBAL VARIABLES section at the top of the script
    ; To change defaults permanently, modify those global variables
    defaultInactivityThreshold := 10000  ; From global: inactivityThreshold
    defaultInactivityJitter := 1000      ; From global: inactivityJitter
    defaultActionBufferTime := 3000      ; From global: actionBufferTime

    ; Create GUI for settings (resizable with minimum size to prevent scrolling)
    settingsGui := Gui("+AlwaysOnTop +Resize +MinSize470x350", "General Settings")
    settingsGui.SetFont("s10", "Segoe UI")

    ; Calculate default values for display (from global variables)
    defaultThresholdSec := Round(defaultInactivityThreshold / 1000)
    defaultJitterSec := Round(defaultInactivityJitter / 1000)
    defaultBufferSec := Round(defaultActionBufferTime / 1000)

    ; Inactivity Threshold (seconds)
    thresholdLabel1 := settingsGui.Add("Text", "x20 y20 w400", "Inactivity Threshold (seconds):")
    thresholdLabel2 := settingsGui.Add("Text", "x20 y35 w400 cGray",
        "How long to wait before starting activity simulation (when user is idle)")
    thresholdEdit := settingsGui.Add("Edit", "x20 y55 w200", Round(inactivityThreshold / 1000))
    thresholdEdit.SetFont("s10", "Segoe UI")
    thresholdDefaultText := settingsGui.Add("Text", "x230 y57 w150", "Default: " . defaultThresholdSec . " seconds"
    )

    ; Inactivity Jitter (seconds)
    jitterLabel1 := settingsGui.Add("Text", "x20 y100 w400", "Inactivity Jitter (±seconds):")
    jitterLabel2 := settingsGui.Add("Text", "x20 y115 w400 cGray",
        "Random variation added to threshold to avoid fixed timing patterns"
    )
    jitterEdit := settingsGui.Add("Edit", "x20 y135 w200", Round(inactivityJitter / 1000))
    jitterEdit.SetFont("s10", "Segoe UI")
    jitterDefaultText := settingsGui.Add("Text", "x230 y137 w150", "Default: ±" . defaultJitterSec . " second")

    ; Action Buffer Time (seconds)
    bufferLabel1 := settingsGui.Add("Text", "x20 y180 w400", "Action Buffer Time (seconds):")
    bufferLabel2 := settingsGui.Add("Text", "x20 y195 w400 cGray",
        "Delay after script actions before checking for real user input")
    bufferEdit := settingsGui.Add("Edit", "x20 y215 w200", Round(actionBufferTime / 1000))
    bufferEdit.SetFont("s10", "Segoe UI")
    bufferDefaultText := settingsGui.Add("Text", "x230 y217 w150", "Default: " . defaultBufferSec . " seconds")

    ; Info text
    noteText := settingsGui.Add("Text", "x20 y260 w400 cGray",
        "Note: Changes take effect immediately.`nEvent settings and mouse click target are available in the tray menu (right-click tray icon).")

    ; Buttons (Cancel acts as close button)
    saveBtn := settingsGui.Add("Button", "x120 y300 w100 h30 Default", "Save")
    cancelBtn := settingsGui.Add("Button", "x230 y300 w100 h30", "Close")
    resetBtn := settingsGui.Add("Button", "x20 y300 w90 h30", "Reset")

    ; Button handlers using closures
    saveBtn.OnEvent("Click", SaveSettingsHandler.Bind(thresholdEdit, jitterEdit, bufferEdit, settingsGui))
    cancelBtn.OnEvent("Click", (*) => settingsGui.Destroy())
    resetBtn.OnEvent("Click", ResetSettingsHandler.Bind(thresholdEdit, jitterEdit, bufferEdit, defaultThresholdSec,
        defaultJitterSec, defaultBufferSec))

    ; Handle window resize - pass all controls that need resizing and settingsGui
    settingsGui.OnEvent("Size", ResizeGeneralSettings.Bind(thresholdEdit, jitterEdit, bufferEdit,
        thresholdLabel1, thresholdLabel2, thresholdDefaultText,
        jitterLabel1, jitterLabel2, jitterDefaultText,
        bufferLabel1, bufferLabel2, bufferDefaultText,
        noteText, saveBtn, cancelBtn, resetBtn, settingsGui))

    ; Show window
    settingsGui.Show("w470 h350")
}

; Helper function to show always-on-top message
ShowAlwaysOnTopMessage(message, title) {
    settingsWinTitle := "General Settings"

    ; Check if settings window exists and get its position
    if (WinExist(settingsWinTitle)) {
        try {
            ; Get settings window position
            WinGetPos(&settingsX, &settingsY, &settingsW, &settingsH, settingsWinTitle)
            ; Calculate message box position (above settings window)
            msgBoxHeight := 120
            msgBoxWidth := 400
            msgX := settingsX + 25
            msgY := Max(10, settingsY - msgBoxHeight - 10)  ; Ensure it's on screen

            ; Create a custom message GUI positioned above the settings window
            msgGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", title)
            msgGui.SetFont("s10", "Segoe UI")
            msgGui.Add("Text", "x10 y10 w380", message)
            okBtn := msgGui.Add("Button", "x160 y80 w80 h30 Default", "OK")
            okBtn.OnEvent("Click", (*) => msgGui.Destroy())
            ; Position above settings window
            msgGui.Show("x" . msgX . " y" . msgY . " w" . msgBoxWidth . " h" . msgBoxHeight)
            ; Bring to front
            WinActivate("ahk_id " . msgGui.Hwnd)
            ; Wait for user to close
            WinWaitClose("ahk_id " . msgGui.Hwnd)
        } catch {
            ; Fallback to regular MsgBox if custom GUI fails
            MsgBox(message, title, "OK")
        }
    } else {
        ; Settings window not open, center on screen with always on top
        try {
            msgGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", title)
            msgGui.SetFont("s10", "Segoe UI")
            msgGui.Add("Text", "x10 y10 w380", message)
            okBtn := msgGui.Add("Button", "x160 y80 w80 h30 Default", "OK")
            okBtn.OnEvent("Click", (*) => msgGui.Destroy())
            ; Center on screen
            msgGui.Show("w400 h120")
            ; Bring to front
            WinActivate("ahk_id " . msgGui.Hwnd)
            ; Wait for user to close
            WinWaitClose("ahk_id " . msgGui.Hwnd)
        } catch {
            ; Fallback to regular MsgBox if custom GUI fails
            MsgBox(message, title, "OK")
        }
    }
}

; Function to save settings
SaveSettingsHandler(thresholdEdit, jitterEdit, bufferEdit, settingsGui, *) {
    global inactivityThreshold, inactivityJitter, actionBufferTime

    ; Validate and save settings
    thresholdValue := Integer(thresholdEdit.Value)
    jitterValue := Integer(jitterEdit.Value)
    bufferValue := Integer(bufferEdit.Value)

    ; Validate threshold (1-60 seconds)
    if (thresholdValue < 1 || thresholdValue > 60) {
        ShowAlwaysOnTopMessage("Inactivity Threshold must be between 1 and 60 seconds!", "Invalid Value")
        return
    }

    ; Validate jitter (0-10 seconds)
    if (jitterValue < 0 || jitterValue > 10) {
        ShowAlwaysOnTopMessage("Inactivity Jitter must be between 0 and 10 seconds!", "Invalid Value")
        return
    }

    ; Validate buffer (1-10 seconds)
    if (bufferValue < 1 || bufferValue > 10) {
        ShowAlwaysOnTopMessage("Action Buffer Time must be between 1 and 10 seconds!", "Invalid Value")
        return
    }

    ; Save settings
    inactivityThreshold := thresholdValue * 1000
    inactivityJitter := jitterValue * 1000
    actionBufferTime := bufferValue * 1000

    ; Settings are runtime-only (no longer saved to INI file)

    ; Show confirmation (positioned above settings window, always on top)
    settingsWinTitle := "General Settings"
    msgBoxText := "Settings saved successfully!`n`n" .
        "Inactivity Threshold: " . thresholdValue . " seconds`n" .
        "Inactivity Jitter: ±" . jitterValue . " seconds`n" .
        "Action Buffer Time: " . bufferValue . " seconds`n`n" .
        "Changes are now active."

    ; Check if settings window exists and get its position
    if (WinExist(settingsWinTitle)) {
        try {
            ; Get settings window position
            WinGetPos(&settingsX, &settingsY, &settingsW, &settingsH, settingsWinTitle)
            ; Calculate message box position (above settings window)
            msgBoxHeight := 200
            msgBoxWidth := 420
            msgX := settingsX + 25
            msgY := Max(10, settingsY - msgBoxHeight - 10)  ; Ensure it's on screen

            ; Create a custom message GUI positioned above the settings window
            msgGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", "Settings Saved")
            msgGui.SetFont("s10", "Segoe UI")
            msgGui.Add("Text", "x10 y10 w400", msgBoxText)
            okBtn := msgGui.Add("Button", "x170 y160 w80 h30 Default", "OK")
            okBtn.OnEvent("Click", (*) => msgGui.Destroy())
            ; Position above settings window
            msgGui.Show("x" . msgX . " y" . msgY . " w" . msgBoxWidth . " h" . msgBoxHeight)
            ; Bring to front
            WinActivate("ahk_id " . msgGui.Hwnd)
            ; Wait for user to close
            WinWaitClose("ahk_id " . msgGui.Hwnd)
        } catch {
            ; Fallback to regular MsgBox if custom GUI fails
            MsgBox(msgBoxText, "Settings Saved", "OK")
        }
    } else {
        ; Settings window not open, center on screen with always on top
        try {
            msgGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", "Settings Saved")
            msgGui.SetFont("s10", "Segoe UI")
            msgGui.Add("Text", "x10 y10 w400", msgBoxText)
            okBtn := msgGui.Add("Button", "x170 y160 w80 h30 Default", "OK")
            okBtn.OnEvent("Click", (*) => msgGui.Destroy())
            ; Center on screen
            msgGui.Show("w420 h200")
            ; Bring to front
            WinActivate("ahk_id " . msgGui.Hwnd)
            ; Wait for user to close
            WinWaitClose("ahk_id " . msgGui.Hwnd)
        } catch {
            ; Fallback to regular MsgBox if custom GUI fails
            MsgBox(msgBoxText, "Settings Saved", "OK")
        }
    }

    LogActivity("Settings", "Updated: Threshold=" . thresholdValue . "s, Jitter=±" . jitterValue . "s, Buffer=" .
        bufferValue . "s")
    settingsGui.Destroy()
}

; Function to reset settings to defaults
ResetSettingsHandler(thresholdEdit, jitterEdit, bufferEdit, defaultThresholdSec, defaultJitterSec, defaultBufferSec, *
) {
    ; Reset to defaults from global variables
    thresholdEdit.Value := defaultThresholdSec
    jitterEdit.Value := defaultJitterSec
    bufferEdit.Value := defaultBufferSec
}

; Function to clear mouse click target position
ClearClickTargetHandler(clickTargetText, setTargetBtn, clearTargetBtn, settingsGui, *) {
    global mouseClickTargetPos

    ; Clear target position
    mouseClickTargetPos := 0

    ; Log that the handler was called
    LogActivity("Mouse Click Target", "Clear button clicked")

    ; Update GUI controls - ensure controls exist and update them
    try {
        if (clickTargetText) {
            clickTargetText.Text := "No target position set"
            clickTargetText.SetFont("cGray")
        }
        if (clearTargetBtn) {
            clearTargetBtn.Enabled := false
        }
    } catch as err {
        ; Log error but continue
        LogActivity("Error", "Failed to update GUI controls: " . err.Message)
    }

    ; Show confirmation above the current settings window (Event Settings / General Settings)
    msgBoxText := "Mouse click target position cleared!`n`n" .
        "Multiple left-click actions will now use the current mouse position."

    ownerHwnd := 0
    try ownerHwnd := settingsGui.Hwnd
    ShowOwnedPopup(ownerHwnd, msgBoxText, "Target Position Cleared")

    LogActivity("Mouse Click Target", "Cleared")
}

; Function to handle General Settings window resize
ResizeGeneralSettings(thresholdEdit, jitterEdit, bufferEdit,
    thresholdLabel1, thresholdLabel2, thresholdDefaultText,
    jitterLabel1, jitterLabel2, jitterDefaultText,
    bufferLabel1, bufferLabel2, bufferDefaultText,
    noteText, saveBtn, cancelBtn, resetBtn, settingsGui,
    guiObj, minMax, width, height) {

    ; Adjust controls when window is resized
    try {
        ; Constants for layout
        marginX := 20
        editFieldMaxWidth := 250  ; Maximum reasonable width for numeric inputs (prevents absurd stretching)
        editFieldMinWidth := 150  ; Minimum width for edit fields
        spacingBetweenEditAndDefault := 10  ; Space between edit field and default text
        defaultTextWidth := 180  ; Width for default text
        minWindowWidthForSideBySide := 400  ; Minimum width to show default text next to edit field
        originalLabelWidth := 400  ; Original label width to maintain text visibility

        ; Adjust available width for controls
        availableWidth := width - (marginX * 2)
        ; Determine if we have enough space to show default text next to edit field
        canShowSideBySide := (width >= minWindowWidthForSideBySide)

        if (canShowSideBySide) {
            ; Normal layout: edit field and default text side by side
            ; Calculate edit field width (reasonable size, not too wide)
            editFieldWidth := Min(editFieldMaxWidth, Max(editFieldMinWidth, availableWidth - defaultTextWidth -
                spacingBetweenEditAndDefault))

            ; Calculate default text position (next to edit field)
            defaultTextX := marginX + editFieldWidth + spacingBetweenEditAndDefault
        } else {
            ; Narrow window: edit field takes available width, default text below
            editFieldWidth := Max(editFieldMinWidth, Min(editFieldMaxWidth, availableWidth))
            defaultTextX := marginX
        }

        ; Calculate label width (ensure minimum width to prevent text truncation, expand if window is larger)
        labelWidth := Max(originalLabelWidth, availableWidth)

        ; Update Inactivity Threshold section
        thresholdLabel1.Move(, , labelWidth)
        thresholdLabel2.Move(, , labelWidth)
        thresholdEdit.Move(, , editFieldWidth)
        if (canShowSideBySide) {
            thresholdDefaultText.Move(defaultTextX, 57, defaultTextWidth)
        } else {
            ; Position default text below edit field when window is narrow
            thresholdDefaultText.Move(defaultTextX, 80, labelWidth)
        }

        ; Update Inactivity Jitter section
        jitterLabel1.Move(, , labelWidth)
        jitterLabel2.Move(, , labelWidth)
        jitterEdit.Move(, , editFieldWidth)
        if (canShowSideBySide) {
            jitterDefaultText.Move(defaultTextX, 137, defaultTextWidth)
        } else {
            ; Position default text below edit field when window is narrow
            jitterDefaultText.Move(defaultTextX, 160, labelWidth)
        }

        ; Update Action Buffer Time section
        bufferLabel1.Move(, , labelWidth)
        bufferLabel2.Move(, , labelWidth)
        bufferEdit.Move(, , editFieldWidth)
        if (canShowSideBySide) {
            bufferDefaultText.Move(defaultTextX, 217, defaultTextWidth)
        } else {
            ; Position default text below edit field when window is narrow
            bufferDefaultText.Move(defaultTextX, 240, labelWidth)
        }

        ; Update note text (responsive width, maintain minimum for readability)
        noteText.Move(, , labelWidth)

        ; Update button positions (maintain original relative positions: Reset at x20, Save at x120, Close at x230)
        ; Original button positions and sizes (exact values from initial creation)
        originalButtonY := 300
        originalResetX := 20
        originalResetWidth := 90
        originalSaveX := 120
        originalSaveWidth := 100
        originalCancelX := 230
        originalCancelWidth := 100
        originalButtonHeight := 30
        originalWindowWidth := 450  ; Original window width

        ; Restore exact original positions when window is at or above original size
        if (width >= originalWindowWidth) {
            ; Window is at or above original size - restore exact original positions
            resetBtn.Move(originalResetX, originalButtonY, originalResetWidth, originalButtonHeight)
            saveBtn.Move(originalSaveX, originalButtonY, originalSaveWidth, originalButtonHeight)
            cancelBtn.Move(originalCancelX, originalButtonY, originalCancelWidth, originalButtonHeight)
        } else {
            ; Window is narrow - maintain spacing but shift left if needed
            resetBtnX := marginX
            saveBtnX := resetBtnX + originalResetWidth + 10
            cancelBtnX := saveBtnX + originalSaveWidth + 10

            ; Ensure buttons don't overflow window
            if (cancelBtnX + originalCancelWidth > width - marginX) {
                ; Scale down button spacing proportionally
                totalButtonWidth := originalResetWidth + originalSaveWidth + originalCancelWidth
                availableButtonSpace := width - (marginX * 2)
                spacing := (availableButtonSpace - totalButtonWidth) / 2
                saveBtnX := resetBtnX + originalResetWidth + spacing
                cancelBtnX := saveBtnX + originalSaveWidth + spacing
            }

            resetBtn.Move(resetBtnX, originalButtonY, originalResetWidth, originalButtonHeight)
            saveBtn.Move(saveBtnX, originalButtonY, originalSaveWidth, originalButtonHeight)
            cancelBtn.Move(cancelBtnX, originalButtonY, originalCancelWidth, originalButtonHeight)
        }

    } catch {
        ; Ignore errors during resize
    }
}

; Function to handle Service Settings window resize
ResizeServiceSettings(serviceListEdit, guiObj, minMax, width, height) {
    ; Keep text box at fixed size (400px width, 100px height for 6 rows) - don't stretch
    ; Only adjust width slightly if window is very small, but keep height fixed
    try {
        fixedWidth := 400
        fixedHeight := 100  ; Fixed height for 6 rows

        ; Only adjust width if window is smaller than needed
        if (width < 450) {
            fixedWidth := width - 50
        }

        ; Always keep height fixed at 100px (6 rows)
        serviceListEdit.Move(, , fixedWidth, fixedHeight)
    } catch {
        ; Ignore errors during resize
    }
}

; ============================================
; NEW FEATURE: SERVICE PAUSE SETTINGS
; ============================================
; Function to show service pause settings dialog
ShowServiceSettings() {
    global pauseServices, serviceCheckEnabled

    ; Create GUI for service settings (resizable with close button)
    serviceGui := Gui("+AlwaysOnTop +Resize", "Service Pause Settings")
    serviceGui.SetFont("s10", "Segoe UI")

    ; Title
    serviceGui.Add("Text", "x20 y20 w560", "Pause script when these services/processes are running:")
    serviceGui.Add("Text", "x20 y40 w560 cGray", "Enter service/process names manually (one per line)")

    ; Enable/Disable checkbox
    enableCheckbox := serviceGui.Add("Checkbox", "x20 y70 w300", "Enable service checking")
    enableCheckbox.Value := serviceCheckEnabled ? 1 : 0

    ; Service list (multi-line edit) - smaller size (6 rows, ~50 characters width)
    serviceGui.Add("Text", "x20 y100 w200", "Service/Process Names (one per line):")
    serviceListEdit := serviceGui.Add("Edit", "x20 y120 w400 h100 Multi VScroll", "")

    ; Placeholder text constant
    placeholderText := "chrome.exe`r`nnotepad.exe`r`nhello.txt`r`nworldmap.exe`r`nd2x.dll"

    ; Populate with current services or show placeholder
    if (pauseServices.Length > 0) {
        serviceListText := ""
        for serviceName in pauseServices {
            serviceListText .= serviceName . "`r`n"
        }
        serviceListEdit.Value := Trim(serviceListText, "`r`n")
    } else {
        ; Show placeholder text (will be cleared when user starts typing)
        serviceListEdit.Value := placeholderText
    }

    ; Clear placeholder when user focuses on edit box
    serviceListEdit.OnEvent("Focus", ClearPlaceholder.Bind(serviceListEdit, placeholderText))

    ; Info text (positioned after text box with proper spacing)
    serviceGui.Add("Text", "x20 y230 w400 cGray",
        "Note: Enter exact service/process names. The script will pause when any of these are running.")

    ; Buttons (positioned with proper spacing, no overlap)
    clearBtn := serviceGui.Add("Button", "x20 y270 w100 h30", "Clear All")
    saveBtn := serviceGui.Add("Button", "x130 y270 w100 h30 Default", "Save")
    cancelBtn := serviceGui.Add("Button", "x240 y270 w100 h30", "Close")

    ; Button handlers
    clearBtn.OnEvent("Click", ClearServiceList.Bind(serviceListEdit))
    saveBtn.OnEvent("Click", SaveServiceSettings.Bind(serviceListEdit, enableCheckbox, serviceGui))
    cancelBtn.OnEvent("Click", (*) => serviceGui.Destroy())

    ; Handle window resize
    serviceGui.OnEvent("Size", ResizeServiceSettings.Bind(serviceListEdit))

    ; Show GUI (resizable, properly sized to avoid overlap)
    serviceGui.Show("w450 h320")
}

; Function to clear service list
ClearServiceList(serviceListEdit, *) {
    serviceListEdit.Value := ""
}

; Function to clear placeholder text when user focuses
ClearPlaceholder(serviceListEdit, placeholderText, *) {
    ; Check if current value matches placeholder
    if (serviceListEdit.Value == placeholderText) {
        serviceListEdit.Value := ""
    }
}

; Function to save service settings
SaveServiceSettings(serviceListEdit, enableCheckbox, serviceGui, *) {
    global pauseServices, serviceCheckEnabled

    ; Get enabled state
    serviceCheckEnabled := enableCheckbox.Value == 1

    ; Parse service names from edit box
    serviceText := serviceListEdit.Value
    pauseServices := []

    ; Check if it's placeholder text and ignore it
    placeholderText := "chrome.exe`r`nnotepad.exe`r`nhello.txt`r`nworldmap.exe`r`nd2x.dll"
    if (serviceText == placeholderText) {
        ; User didn't enter anything, just placeholder - don't save it
        serviceText := ""
    }

    if (serviceText != "") {
        ; Split by newlines
        services := StrSplit(serviceText, "`n")
        for serviceLine in services {
            serviceName := Trim(serviceLine, " `r`t")
            if (serviceName != "") {
                pauseServices.Push(serviceName)
            }
        }
    }

    ; Show confirmation
    serviceCount := pauseServices.Length
    if (serviceCheckEnabled && serviceCount > 0) {
        serviceList := ""
        for i, serviceName in pauseServices {
            if (i <= 5) {
                serviceList .= serviceName . ", "
            } else {
                serviceList := Trim(serviceList, ", ") . "... and " . (serviceCount - 5) . " more"
                break
            }
        }
        if (serviceCount <= 5) {
            serviceList := Trim(serviceList, ", ")
        }

        MsgBox(
            "Service pause settings saved!`n`n" .
            "Service checking: " . (serviceCheckEnabled ? "Enabled" : "Disabled") . "`n" .
            "Services to monitor: " . serviceCount . "`n" .
            "Services: " . serviceList . "`n`n" .
            "Script will pause when any of these services are running.",
            "Service Settings Saved",
            "OK"
        )
    } else if (serviceCheckEnabled && serviceCount == 0) {
        MsgBox(
            "Service checking is enabled but no services are configured.`n`n" .
            "Please add at least one service name.",
            "No Services Configured",
            "OK"
        )
        return
    } else {
        MsgBox(
            "Service pause settings saved!`n`n" .
            "Service checking: Disabled",
            "Service Settings Saved",
            "OK"
        )
    }

    LogActivity("Service Settings", "Updated: " . serviceCount . " service(s), Enabled: " . (serviceCheckEnabled ?
        "Yes" : "No"))
    serviceGui.Destroy()
}

; Custom hotkey: Ctrl+Alt+Shift+T (unused by browsers, Windows, or editors)
^!+t:: {  ; Ctrl+Alt+Shift+T: Schedule Auto-Quit
    global scheduledQuitTime

    ; If already scheduled, offer to cancel
    if (scheduledQuitTime != 0) {
        result := MsgBox(
            "Auto-quit is already scheduled.`n`n" .
            "Do you want to cancel the scheduled auto-quit?",
            "Cancel Scheduled Auto-Quit",
            "YesNo"
        )
        if (result == "Yes") {
            scheduledQuitTime := 0
            SetTimer(CheckScheduledQuit, 0)
            MsgBox("Scheduled auto-quit has been cancelled.", "Cancelled", "OK")
            LogActivity("Scheduled Quit", "Cancelled scheduled auto-quit")
            return
        } else {
            return
        }
    }

    ; Prompt user for hours and minutes (format: HH:MM or just hours)
    ; InputBox(Prompt, Title, Options, Default)
    hoursInput := InputBox(
        "Enter time before auto-quit:`n`n" .
        "Format: HH:MM (e.g., 2:30 for 2 hours 30 minutes)`n" .
        "Or just hours (e.g., 3 for 3 hours)`n`n" .
        "Script will automatically quit after the specified time.`n`n" .
        "Maximum: 24:00 (24 hours)`n`n" .
        "Example: 2:30 or 3",
        "Schedule Auto-Quit",
        "",
        "2:30"
    )

    ; Check if user cancelled
    if (hoursInput.Result != "OK" || hoursInput.Value == "") {
        return
    }

    ; Parse input - check if it contains colon (HH:MM format)
    inputValue := Trim(hoursInput.Value)
    totalMilliseconds := 0

    if (InStr(inputValue, ":")) {
        ; Format: HH:MM
        parts := StrSplit(inputValue, ":")
        if (parts.Length != 2) {
            MsgBox("Invalid format! Please use HH:MM (e.g., 2:30) or just hours (e.g., 3)", "Invalid Format", "OK")
            return
        }

        hours := Integer(parts[1])
        minutes := Integer(parts[2])

        ; Validate hours (0-24)
        if (hours < 0 || hours > 24) {
            MsgBox("Hours must be between 0 and 24!", "Invalid Hours", "OK")
            return
        }

        ; Validate minutes (0-59)
        if (minutes < 0 || minutes > 59) {
            MsgBox("Minutes must be between 0 and 59!", "Invalid Minutes", "OK")
            return
        }

        ; Check total time doesn't exceed 24 hours
        if (hours == 24 && minutes > 0) {
            MsgBox("Maximum time is 24:00 (24 hours)!", "Invalid Time", "OK")
            return
        }

        ; Calculate total milliseconds
        totalMilliseconds := (hours * 3600000) + (minutes * 60000)

        ; Display format for confirmation
        timeDisplay := hours . " hour(s) " . minutes . " minute(s)"
    } else {
        ; Format: Just hours
        hours := Integer(inputValue)

        ; Validate hours (1-24)
        if (hours < 1 || hours > 24) {
            MsgBox("Hours must be between 1 and 24!", "Invalid Hours", "OK")
            return
        }

        ; Calculate total milliseconds
        totalMilliseconds := hours * 3600000

        ; Display format for confirmation
        timeDisplay := hours . " hour(s)"
    }

    ; Calculate quit time (current time + total milliseconds)
    scheduledQuitTime := A_TickCount + totalMilliseconds

    ; Start timer to check every minute if it's time to quit
    SetTimer(CheckScheduledQuit, 60000)  ; Check every 60 seconds

    ; Calculate time remaining for display
    totalSecondsRemaining := (scheduledQuitTime - A_TickCount) / 1000
    hoursRemaining := Floor(totalSecondsRemaining / 3600)
    minutesRemaining := Floor((totalSecondsRemaining - (hoursRemaining * 3600)) / 60)

    ; Format time remaining display
    if (hoursRemaining > 0 && minutesRemaining > 0) {
        timeRemainingDisplay := hoursRemaining . "h " . minutesRemaining . "m"
    } else if (hoursRemaining > 0) {
        timeRemainingDisplay := hoursRemaining . "h"
    } else {
        timeRemainingDisplay := minutesRemaining . "m"
    }

    ; Show confirmation
    MsgBox(
        "Auto-quit scheduled!`n`n" .
        "Script will quit after: " . timeDisplay . "`n`n" .
        "Time remaining: " . timeRemainingDisplay . "`n`n" .
        "Press Ctrl+Alt+Shift+T again to cancel.",
        "Scheduled Auto-Quit",
        "OK"
    )

    LogActivity("Scheduled Quit", "Scheduled to quit after " . timeDisplay)
}

; Function to check if scheduled quit time has been reached
CheckScheduledQuit() {
    global scheduledQuitTime

    ; If no quit scheduled, do nothing
    if (scheduledQuitTime == 0) {
        return
    }

    ; Check if current time has reached or passed scheduled quit time
    if (A_TickCount >= scheduledQuitTime) {
        ; Time to quit!
        LogActivity("Scheduled Quit", "Auto-quit triggered - script will exit")

        ; Stop the timer
        SetTimer(CheckScheduledQuit, 0)

        ; Quit the script (sleep PC functionality removed)
        ExitApp()
    }
}

; Function to put computer to sleep (called via OnExit if scheduled)
PutComputerToSleep() {
    ; Use Windows API to put computer to sleep
    ; SetSuspendState(0 = sleep, 1 = hibernate, 0 = force, 0 = disable wake events)
    try {
        ; Load PowrProf.dll and call SetSuspendState
        DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
    } catch {
        ; Fallback method 1: Use rundll32 to call SetSuspendState
        try {
            Run("rundll32.exe powrprof.dll,SetSuspendState 0,1,0", , "Hide")
            Sleep(1000)  ; Give it a moment to execute
        } catch {
            ; Fallback method 2: Use shutdown command (hibernate)
            try {
                Run("shutdown.exe /h /f", , "Hide")
                Sleep(1000)
            } catch {
                ; Last resort: Try direct API call with different parameters
                try {
                    DllCall("SetSuspendState", "Int", 0, "Int", 0, "Int", 0)
                }
            }
        }
    }
}

; Enhanced OnExit handler (sleep functionality removed, only quit remains)
; This extends the existing OnExit functionality without replacing it
OnExit(ExitReason, ExitCode) {
    global scheduledQuitTime

    ; Sleep PC functionality removed - only quit script when scheduled time completes
    ; Script will quit automatically after scheduled time, but PC will not sleep

    ; Clean up timers (existing cleanup logic)
    SetTimer(CheckInactivity, 0)
    SetTimer(SimulateHuman, 0)
    SetTimer(CheckScheduledQuit, 0)
    SetTimer(CheckUserInput, 0)
    SetTimer(CheckServiceStatus, 0)
}

; Real-time activity monitor GUI
ToggleRealtimeMonitor() {
    global realtimeMonitorGui, realtimeMonitorActive

    if (realtimeMonitorActive && WinExist("ahk_id " . realtimeMonitorGui)) {
        ; Close monitor if already open
        try {
            Gui(realtimeMonitorGui).Destroy()
        }
        realtimeMonitorActive := false
        ; Monitor closed
    } else {
        ; Open/create monitor
        CreateRealtimeMonitor()
    }
}

CreateRealtimeMonitor() {
    global realtimeMonitorGui, realtimeMonitorActive, currentActivity, simulationActive, pausedByUser

    ; Destroy existing GUI if any
    if (realtimeMonitorGui != 0) {
        try {
            Gui(realtimeMonitorGui).Destroy()
        }
    }

    ; Create new GUI
    realtimeMonitorGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", "Real-time Activity Monitor")
    realtimeMonitorGui.SetFont("s10", "Consolas")

    ; Title
    realtimeMonitorGui.Add("Text", "x10 y10 w400 Center", "🔴 REAL-TIME ACTIVITY MONITOR")
    realtimeMonitorGui.Add("Text", "x10 y35 w400 Center cGray", "Press Ctrl+Alt+M to close")

    ; Current activity display (large, prominent)
    currentActivityCtrl := realtimeMonitorGui.Add("Text", "x10 y60 w400 h40 Center vCurrentActivity",
        currentActivity)
    currentActivityCtrl.SetFont("s14 Bold")

    ; Status info
    realtimeMonitorGui.Add("Text", "x10 y110 w400", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    realtimeMonitorGui.Add("Text", "x10 y130 w200", "Script Status:")
    realtimeMonitorGui.Add("Text", "x220 y130 w190 vStatusText", pausedByUser ? "PAUSED" : (simulationActive ?
        "ACTIVE" :
            "MONITORING"))

    realtimeMonitorGui.Add("Text", "x10 y155 w200", "Current Action:")
    realtimeMonitorGui.Add("Text", "x220 y155 w190 vActionText", currentActivity)

    ; Recent activities (last 10)
    realtimeMonitorGui.Add("Text", "x10 y180 w400", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    realtimeMonitorGui.Add("Text", "x10 y200 w400", "Recent Activities:")
    realtimeMonitorGui.Add("Edit", "x10 y220 w400 h150 ReadOnly vActivityList", "")

    ; Update button
    realtimeMonitorGui.Add("Button", "x150 y380 w120 h30", "Refresh", (*) => UpdateRealtimeMonitor())

    ; Show GUI
    realtimeMonitorGui.Show("w420 h420")
    realtimeMonitorActive := true

    ; Start update timer (updates every 500ms for real-time feel)
    SetTimer(UpdateRealtimeMonitor, 500)

    ; Initial update
    UpdateRealtimeMonitor()
}

UpdateRealtimeMonitor() {
    global realtimeMonitorGui, realtimeMonitorActive, currentActivity, simulationActive, pausedByUser, activityLog

    if (!realtimeMonitorActive || !WinExist("ahk_id " . realtimeMonitorGui)) {
        ; GUI closed, stop timer
        SetTimer(UpdateRealtimeMonitor, 0)
        realtimeMonitorActive := false
        return
    }

    try {
        ; Get controls
        statusTextCtrl := realtimeMonitorGui["StatusText"]
        actionTextCtrl := realtimeMonitorGui["ActionText"]
        currentActivityCtrl := realtimeMonitorGui["CurrentActivity"]
        activityListCtrl := realtimeMonitorGui["ActivityList"]

        ; Update current activity
        status := pausedByUser ? "PAUSED" : (simulationActive ? "ACTIVE" : "MONITORING")
        statusTextCtrl.Text := status
        actionTextCtrl.Text := currentActivity
        currentActivityCtrl.Text := currentActivity

        ; Update activity list (last 10 entries)
        logCount := activityLog.Length
        activityListText := ""
        if (logCount > 0) {
            startIdx := Max(1, logCount - 9)  ; Last 10 entries
            loop (logCount - startIdx + 1) {
                idx := logCount - A_Index + 1
                if (idx >= startIdx && idx <= logCount) {
                    activityListText .= activityLog[idx] . "`r`n"
                }
            }
        } else {
            activityListText := "No activities yet..."
        }
        activityListCtrl.Text := activityListText

        ; Color code based on status
        if (pausedByUser) {
            statusTextCtrl.SetFont("cRed")
        } else if (simulationActive) {
            statusTextCtrl.SetFont("cGreen")
        } else {
            statusTextCtrl.SetFont("cBlue")
        }

    } catch {
        ; GUI might be closing
    }
}

; Function to show detailed script status with activity log
ShowScriptStatus() {
    global simulationActive, pausedByUser, lastInputTime, inactivityThreshold, activityLog

    ; Calculate uptime
    uptime := A_TickCount
    uptimeSeconds := Round(uptime / 1000)
    uptimeMinutes := Round(uptimeSeconds / 60)
    uptimeHours := Round(uptimeMinutes / 60)

    ; Get current status
    status := pausedByUser ? "PAUSED" : (simulationActive ? "ACTIVE" : "MONITORING")

    ; Build status message
    statusMsg := "=== Script Status ===" . "`n"
    statusMsg .= "Status: " . status . "`n"
    statusMsg .= "Uptime: " . uptimeHours . "h " . Mod(uptimeMinutes, 60) . "m " . Mod(uptimeSeconds, 60) . "s`n"
    statusMsg .= "Simulation: " . (simulationActive ? "Running" : "Waiting for inactivity") . "`n"
    statusMsg .= "Paused: " . (pausedByUser ? "Yes" : "No") . "`n"
    statusMsg .= "`n"
    statusMsg .= "=== Recent Activity Log ===" . "`n"

    ; Show last 20 activities (most recent first)
    logCount := activityLog.Length
    if (logCount == 0) {
        statusMsg .= "No activities yet - script monitoring..." . "`n"
    } else {
        ; Show last 20 entries (reverse order - newest first)
        startIdx := Max(1, logCount - 19)
        loop (logCount - startIdx + 1) {
            idx := logCount - A_Index + 1
            if (idx >= startIdx && idx <= logCount) {
                statusMsg .= activityLog[idx] . "`n"
            }
        }
    }

    statusMsg .= "`n"
    statusMsg .= "Press Ctrl+Alt+S to refresh status`n"
    statusMsg .= "`n"
    statusMsg .= "Note: Browser keyboard/mouse testers WILL detect script activities.`n"
    statusMsg .= "This is normal - use activity log above to verify script is working."

    ; Show in message box for better visibility
    MsgBox(statusMsg, "Work Tracker Stealth - Status & Activity Log", "OK")

    ; Status shown in message box
}

; ============================================
; SYSTRAY MENU - Exit and Sleep Setting options
; ============================================
A_TrayMenu.Delete()  ; Clear default menu
A_TrayMenu.Add(trayToggleMenuCurrentLabel := "Toggle Simulation", (*) => TogglePauseState("Tray Menu"))
A_TrayMenu.Add()  ; Separator
A_TrayMenu.Add("Event Settings", (*) => ShowEventSettings())
A_TrayMenu.Add("General Settings (Ctrl+Alt+Shift+S)", (*) => Send("^!+s"))
A_TrayMenu.Add("Auto-Quit setting (Ctrl+Alt+Shift+T)", (*) => Send("^!+t"))
A_TrayMenu.Add("Service Pause Settings", (*) => ShowServiceSettings())
A_TrayMenu.Add()  ; Separator
A_TrayMenu.Add("Exit (Ctrl+Alt+Q)", (*) => ExitApp())

; Function to update tray icon based on simulation state
UpdateTrayIcon() {
    global simulationActive, pausedByUser

    try {
        if (pausedByUser) {
            ; Paused state - Pause icon (shell32.dll icon 240 resembles "||")
            TraySetIcon("shell32.dll", 240)
        } else if (simulationActive) {
            ; Active state - Red X icon (shell32.dll icon 27 = error/red X)
            TraySetIcon("shell32.dll", 27)
        } else {
            ; Idle/monitoring state - Desktop/PC icon (shell32.dll icon 34 = desktop/computer)
            TraySetIcon("shell32.dll", 34)
        }
    } catch {
        ; If icon setting fails, continue silently
    }

    UpdateTrayToggleMenu()
}

; Set initial desktop icon (default state)
UpdateTrayIcon()

UpdateTrayToggleMenu() {
    global trayToggleMenuCurrentLabel, pausedByUser

    if (trayToggleMenuCurrentLabel == "") {
        return
    }

    newLabel := pausedByUser ? "Play ▶ Resume" : "Pause | |"
    currentLabel := trayToggleMenuCurrentLabel

    if (currentLabel != newLabel) {
        try {
            A_TrayMenu.Rename(currentLabel, newLabel)
            trayToggleMenuCurrentLabel := newLabel
        } catch {
            return
        }
    }

    currentLabel := trayToggleMenuCurrentLabel
    try {
        iconIndex := pausedByUser ? 239 : 240  ; shell32.dll icons for play/pause
        A_TrayMenu.SetIcon(currentLabel, "shell32.dll", iconIndex)
    } catch {
        ; Ignore icon errors
    }
}

; ============================================
; INITIALIZATION
; ============================================
; Load event settings from INI file
LoadEventSettings()

; Initialize last input time
lastInputTime := A_TickCount
lastKnownInputTime := GetLastInputInfo()

; If no previous input detected, initialize with current time
if (lastKnownInputTime == 0) {
    lastKnownInputTime := DllCall("kernel32\GetTickCount", "UInt")
}

; Start inactivity check timer (every 5 seconds)
; This will detect when user becomes inactive and start simulation
SetTimer(CheckInactivity, 5000)

; Start user input check timer (every 200ms for immediate icon updates)
; This will detect when user becomes active and pause simulation
SetTimer(CheckUserInput, 200)

; Function to check services periodically
CheckServiceStatus() {
    global serviceCheckEnabled, simulationActive
    if (serviceCheckEnabled && IsPauseServiceRunning()) {
        if (simulationActive) {
            simulationActive := false
            SetTimer(SimulateHuman, 0)
            LogActivity("Service Check", "Paused - Service is running")
            UpdateTrayIcon()
        }
    }
}

; Start service check timer (every 10 seconds)
; This will pause script when configured services are running
SetTimer(CheckServiceStatus, 10000)

; Initial activity log entry
LogActivity("Script", "Started - Monitoring inactivity")
currentActivity := "⏳ Idle - Monitoring for inactivity (10s threshold)"

; No initial notification - silent start

; ============================================
; CLEANUP ON EXIT
; ============================================
; Note: OnExit is now defined in the Scheduled Quit section above
; This section kept for reference but OnExit handler is in new feature section
