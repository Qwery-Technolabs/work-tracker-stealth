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

; Service-based pause tracking
pauseServices := []  ; Array of service names to pause when running
serviceCheckEnabled := false  ; Whether to check services

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
        if (currentInputTime > 0 && currentInputTime != lastScriptInputTime && currentInputTime != lastKnownInputTime) {
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
    global scriptActionStartTime, scriptActionEndTime

    if (!simulationActive || pausedByUser) {
        return
    }

    ; Mark script action start time (for distinguishing script vs human input)
    scriptActionStartTime := DllCall("kernel32\GetTickCount", "UInt")

    ; Set flag to indicate script is performing actions (prevents self-pause)
    scriptActionInProgress := true

    ; Random action distribution: 30% mouse, 30% scroll, 25% keys, 10% window switch, 5% hardware
    ; Scroll has 30% ratio as standalone action, plus automatic scroll after mouse movement
    randAction := Random(1, 100)

    ; Log simulation start
    LogActivity("Simulation", "Action triggered")

    if (randAction <= 30) {
        ; Mouse movement (30%) - scroll will trigger automatically 10 seconds after this
        currentActivity := "🖱️ Mouse Movement - Random paths & oval shapes"
        PerformMouseMovement()
        currentActivity := "✅ Mouse Movement Complete (scroll scheduled in 10s)"
    } else if (randAction <= 60) {
        ; Scroll wheel (30%) - standalone scroll action
        currentActivity := "🖱️ Mouse Scroll - Random scroll up/down"
        PerformScrollWheel()
        currentActivity := "✅ Scroll Complete"
    } else if (randAction <= 85) {
        ; Key presses (25%)
        currentActivity := "⌨️ Key Press - Sending modifier keys"
        PerformKeyPresses()
        currentActivity := "✅ Key Press Complete"
    } else if (randAction <= 95) {
        ; Window switching with Alt+Tab (10%)
        currentActivity := "🪟 Window Switch - Switching between windows (Alt+Tab)"
        PerformWindowSwitch()
        currentActivity := "✅ Window Switch Complete"
    } else {
        ; Hardware adjustment - brightness/volume (5% - natural laptop usage)
        currentActivity := "⚙️ Hardware Adjust - Adjusting brightness/volume"
        PerformHardwareAdjust()
        currentActivity := "✅ Hardware Adjust Complete"
    }

    ; Mark script action end time and clear flag after action completes
    ; This allows input detection to distinguish between script actions and human input
    ; Calculate delay based on action type to ensure action is fully complete
    if (randAction <= 30) {
        ; Mouse movement - speedy, clear after 500ms (longer for oval shapes that repeat 10-15x)
        ; Oval shapes take longer due to 10-15 repetitions
        SetTimer(ClearScriptActionFlag, -500)
    } else if (randAction <= 60) {
        ; Scroll wheel - quick, clear after 200ms
        SetTimer(ClearScriptActionFlag, -200)
    } else if (randAction <= 85) {
        ; Key presses - quick, clear after 300ms
        SetTimer(ClearScriptActionFlag, -300)
    } else if (randAction <= 95) {
        ; Window switch - takes a few seconds, clear after 3 seconds
        SetTimer(ClearScriptActionFlag, -3000)
    } else {
        ; Hardware adjust - quick, clear after 200ms
        SetTimer(ClearScriptActionFlag, -200)
    }

    ; Schedule next action - reduced to 5-10 seconds (random but less than before)
    ; All actions now happen more frequently for better activity simulation
    if (randAction <= 30) {
        ; Mouse movement - every 5-10 seconds (speedy)
        nextDelay := Random(5000, 10000)
    } else if (randAction <= 60) {
        ; Scroll wheel - every 5-10 seconds (speedy)
        nextDelay := Random(5000, 10000)
    } else if (randAction <= 85) {
        ; Key presses - every 5-10 seconds (reduced from 8-15)
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
    global simulationActive, pausedByUser
    pausedByUser := !pausedByUser

    if (pausedByUser) {
        simulationActive := false
        SetTimer(SimulateHuman, 0)
        LogActivity("User", "Paused simulation")
        UpdateTrayIcon()  ; Update to desktop icon when paused
    } else {
        LogActivity("User", "Resumed simulation")
        UpdateTrayIcon()  ; Update to red X icon when active
    }
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

; ============================================
; NEW FEATURE: SCHEDULED AUTO-QUIT
; ============================================
; Global variable to track scheduled quit time (0 = not scheduled)
scheduledQuitTime := 0

; ============================================
; NEW FEATURE: GENERAL SETTINGS
; ============================================
; Custom hotkey: Ctrl+Alt+Shift+S (unused by browsers, Windows, or editors)
^!+s:: {  ; Ctrl+Alt+Shift+S: Open General Settings
    ShowGeneralSettings()
}

; Function to show general settings dialog
ShowGeneralSettings() {
    global inactivityThreshold, inactivityJitter, actionBufferTime

    ; Store original default values from global variables (these are the script defaults)
    ; These values come from the GLOBAL VARIABLES section at the top of the script
    ; To change defaults permanently, modify those global variables
    defaultInactivityThreshold := 10000  ; From global: inactivityThreshold
    defaultInactivityJitter := 1000      ; From global: inactivityJitter
    defaultActionBufferTime := 3000      ; From global: actionBufferTime

    ; Create GUI for settings (resizable)
    settingsGui := Gui("+AlwaysOnTop +Resize", "General Settings")
    settingsGui.SetFont("s10", "Segoe UI")

    ; Calculate default values for display (from global variables)
    defaultThresholdSec := Round(defaultInactivityThreshold / 1000)
    defaultJitterSec := Round(defaultInactivityJitter / 1000)
    defaultBufferSec := Round(defaultActionBufferTime / 1000)

    ; Inactivity Threshold (seconds)
    settingsGui.Add("Text", "x20 y20 w400", "Inactivity Threshold (seconds):")
    settingsGui.Add("Text", "x20 y35 w400 cGray",
        "How long to wait before starting activity simulation (when user is idle)")
    thresholdEdit := settingsGui.Add("Edit", "x20 y55 w200", Round(inactivityThreshold / 1000))
    thresholdEdit.SetFont("s10", "Segoe UI")
    settingsGui.Add("Text", "x230 y57 w150", "Default: " . defaultThresholdSec . " seconds")

    ; Inactivity Jitter (seconds)
    settingsGui.Add("Text", "x20 y100 w400", "Inactivity Jitter (±seconds):")
    settingsGui.Add("Text", "x20 y115 w400 cGray", "Random variation added to threshold to avoid fixed timing patterns"
    )
    jitterEdit := settingsGui.Add("Edit", "x20 y135 w200", Round(inactivityJitter / 1000))
    jitterEdit.SetFont("s10", "Segoe UI")
    settingsGui.Add("Text", "x230 y137 w150", "Default: ±" . defaultJitterSec . " second")

    ; Action Buffer Time (seconds)
    settingsGui.Add("Text", "x20 y180 w400", "Action Buffer Time (seconds):")
    settingsGui.Add("Text", "x20 y195 w400 cGray", "Delay after script actions before checking for real user input")
    bufferEdit := settingsGui.Add("Edit", "x20 y215 w200", Round(actionBufferTime / 1000))
    bufferEdit.SetFont("s10", "Segoe UI")
    settingsGui.Add("Text", "x230 y217 w150", "Default: " . defaultBufferSec . " seconds")

    ; Info text
    settingsGui.Add("Text", "x20 y260 w400 cGray",
        "Note: Changes take effect immediately.`nRestart script to fully apply changes.")

    ; Buttons (Cancel acts as close button)
    saveBtn := settingsGui.Add("Button", "x120 y300 w100 h30 Default", "Save")
    cancelBtn := settingsGui.Add("Button", "x230 y300 w100 h30", "Close")
    resetBtn := settingsGui.Add("Button", "x20 y300 w90 h30", "Reset")

    ; Button handlers using closures
    saveBtn.OnEvent("Click", SaveSettingsHandler.Bind(thresholdEdit, jitterEdit, bufferEdit, settingsGui))
    cancelBtn.OnEvent("Click", (*) => settingsGui.Destroy())
    resetBtn.OnEvent("Click", ResetSettingsHandler.Bind(thresholdEdit, jitterEdit, bufferEdit, defaultThresholdSec,
        defaultJitterSec, defaultBufferSec))

    ; Handle window resize
    settingsGui.OnEvent("Size", ResizeGeneralSettings.Bind(thresholdEdit, jitterEdit, bufferEdit))

    ; Show GUI (resizable)
    settingsGui.Show("w450 h350")
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
        MsgBox("Inactivity Threshold must be between 1 and 60 seconds!", "Invalid Value", "OK")
        return
    }

    ; Validate jitter (0-10 seconds)
    if (jitterValue < 0 || jitterValue > 10) {
        MsgBox("Inactivity Jitter must be between 0 and 10 seconds!", "Invalid Value", "OK")
        return
    }

    ; Validate buffer (1-10 seconds)
    if (bufferValue < 1 || bufferValue > 10) {
        MsgBox("Action Buffer Time must be between 1 and 10 seconds!", "Invalid Value", "OK")
        return
    }

    ; Save settings
    inactivityThreshold := thresholdValue * 1000
    inactivityJitter := jitterValue * 1000
    actionBufferTime := bufferValue * 1000

    ; Show confirmation
    MsgBox(
        "Settings saved successfully!`n`n" .
        "Inactivity Threshold: " . thresholdValue . " seconds`n" .
        "Inactivity Jitter: ±" . jitterValue . " seconds`n" .
        "Action Buffer Time: " . bufferValue . " seconds`n`n" .
        "Changes are now active.",
        "Settings Saved",
        "OK"
    )

    LogActivity("Settings", "Updated: Threshold=" . thresholdValue . "s, Jitter=±" . jitterValue . "s, Buffer=" .
        bufferValue . "s")
    settingsGui.Destroy()
}

; Function to reset settings to defaults
ResetSettingsHandler(thresholdEdit, jitterEdit, bufferEdit, defaultThresholdSec, defaultJitterSec, defaultBufferSec, *) {
    ; Reset to defaults from global variables
    thresholdEdit.Value := defaultThresholdSec
    jitterEdit.Value := defaultJitterSec
    bufferEdit.Value := defaultBufferSec
}

; Function to handle General Settings window resize
ResizeGeneralSettings(thresholdEdit, jitterEdit, bufferEdit, guiObj, minMax, width, height) {
    ; Adjust controls when window is resized
    try {
        thresholdEdit.Move(, , width - 250)
        jitterEdit.Move(, , width - 250)
        bufferEdit.Move(, , width - 250)
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
    currentActivityCtrl := realtimeMonitorGui.Add("Text", "x10 y60 w400 h40 Center vCurrentActivity", currentActivity)
    currentActivityCtrl.SetFont("s14 Bold")

    ; Status info
    realtimeMonitorGui.Add("Text", "x10 y110 w400", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    realtimeMonitorGui.Add("Text", "x10 y130 w200", "Script Status:")
    realtimeMonitorGui.Add("Text", "x220 y130 w190 vStatusText", pausedByUser ? "PAUSED" : (simulationActive ? "ACTIVE" :
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
A_TrayMenu.Add("General Settings (Ctrl+Alt+Shift+S)", (*) => Send("^!+s"))
A_TrayMenu.Add("Auto-Quit setting (Ctrl+Alt+Shift+T)", (*) => Send("^!+t"))
A_TrayMenu.Add("Service Pause Settings", (*) => ShowServiceSettings())
A_TrayMenu.Add()  ; Separator
A_TrayMenu.Add("Exit (Ctrl+Alt+Q)", (*) => ExitApp())

; Function to update tray icon based on simulation state
UpdateTrayIcon() {
    global simulationActive, pausedByUser

    try {
        if (simulationActive && !pausedByUser) {
            ; Active state - Red X icon (shell32.dll icon 27 = error/red X)
            TraySetIcon("shell32.dll", 27)
        } else {
            ; Idle/Paused state - Desktop/PC icon (shell32.dll icon 34 = desktop/computer)
            TraySetIcon("shell32.dll", 34)
        }
    } catch {
        ; If icon setting fails, continue silently
    }
}

; Set initial desktop icon (default state)
UpdateTrayIcon()

; ============================================
; INITIALIZATION
; ============================================
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
