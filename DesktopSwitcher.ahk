#Requires AutoHotkey v2.0
#SingleInstance Force
DetectHiddenWindows true

; Ctrl+Win+1..9 -> jump to desktop 1..9, Ctrl+Win+0 -> desktop 10
; Ctrl+Win+Left/Right keep working as usual.
; VirtualDesktopAccessor.dll must sit next to this script for direct jumps;
; without it, the script falls back to stepping through desktops.

global VDA := DllCall("LoadLibrary", "Str", A_ScriptDir "\VirtualDesktopAccessor.dll", "Ptr")
global GoToDesktopNumberProc := VDA ? DllCall("GetProcAddress", "Ptr", VDA, "AStr", "GoToDesktopNumber", "Ptr") : 0
global GetDesktopCountProc := VDA ? DllCall("GetProcAddress", "Ptr", VDA, "AStr", "GetDesktopCount", "Ptr") : 0
global GetCurrentDesktopNumberProc := VDA ? DllCall("GetProcAddress", "Ptr", VDA, "AStr", "GetCurrentDesktopNumber", "Ptr") : 0
global PinWindowProc := VDA ? DllCall("GetProcAddress", "Ptr", VDA, "AStr", "PinWindow", "Ptr") : 0
global IsPinnedWindowProc := VDA ? DllCall("GetProcAddress", "Ptr", VDA, "AStr", "IsPinnedWindow", "Ptr") : 0

; Transition settings
global FADE_ENABLED := true
global FADE_IN_MS := 220        ; time to dim the screen
global FADE_HOLD_MS := 80       ; pause at the darkest point while the desktop switches
global FADE_OUT_MS := 320       ; time to reveal the new desktop
global FADE_MAX_OPACITY := 235  ; 0-255, how dark it gets at the peak
global SHOW_LABEL := true       ; show "Desktop N" during the switch

global Switching := false

^#1::GoToDesktop(1)
^#2::GoToDesktop(2)
^#3::GoToDesktop(3)
^#4::GoToDesktop(4)
^#5::GoToDesktop(5)
^#6::GoToDesktop(6)
^#7::GoToDesktop(7)
^#8::GoToDesktop(8)
^#9::GoToDesktop(9)
^#0::GoToDesktop(10)

GoToDesktop(target) {
    global Switching
    if Switching
        return
    if (GoToDesktopNumberProc && GetDesktopCountProc) {
        count := DllCall(GetDesktopCountProc, "Int")
        if (count > 0) {
            target := Min(target, count)
            if (GetCurrentDesktopNumberProc && DllCall(GetCurrentDesktopNumberProc, "Int") = target - 1)
                return
            Switching := true
            try {
                if FADE_ENABLED
                    FadeSwitch(target)
                else
                    DllCall(GoToDesktopNumberProc, "Int", target - 1, "Int")
            }
            Switching := false
            return
        }
    }
    StepToDesktop(target)
}

FadeSwitch(target) {
    global Overlay
    ShowOverlay(target, 0)
    pinned := EnsurePinned()
    Fade(Overlay, 0, FADE_MAX_OPACITY, FADE_IN_MS)

    DllCall(GoToDesktopNumberProc, "Int", target - 1, "Int")

    ; If pinning failed, the overlay stayed behind on the old desktop,
    ; so rebuild it on the new desktop to fade out from.
    if !pinned {
        Overlay.Destroy()
        Overlay := 0
        ShowOverlay(target, FADE_MAX_OPACITY)
    }
    Sleep FADE_HOLD_MS
    Fade(Overlay, FADE_MAX_OPACITY, 0, FADE_OUT_MS)
    Overlay.Hide()
}

; The overlay is created once and reused. It is owned by a hidden tool window,
; which keeps it off the taskbar while still letting Windows pin it to all
; desktops (tool windows themselves can't be pinned).
global Overlay := 0, OverlayOwner := 0, OverlayLabel := 0

ShowOverlay(target, opacity) {
    global Overlay, OverlayOwner, OverlayLabel
    if !Overlay {
        if !OverlayOwner
            OverlayOwner := Gui("-Caption +ToolWindow")
        Overlay := Gui("+AlwaysOnTop -Caption +E0x20 -DPIScale +Owner" OverlayOwner.Hwnd)
        Overlay.BackColor := "000000"
        Overlay.SetFont("s36 cWhite", "Segoe UI Light")
        OverlayLabel := Overlay.Add("Text", "x0 y0 w10 h80 Center BackgroundTrans")
        ; Stop Windows from playing its own show/hide animation on the overlay.
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", Overlay.Hwnd, "UInt", 3, "Int*", 1, "UInt", 4)
    }
    ; Cover every monitor (virtual screen). 1px short of full height so Windows
    ; doesn't treat it as a fullscreen app, which blanks the display briefly.
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79) - 1
    OverlayLabel.Move(-vx, -vy + A_ScreenHeight // 2 - 40, A_ScreenWidth, 80)
    OverlayLabel.Value := SHOW_LABEL ? "Desktop " target : ""
    WinSetTransparent opacity, Overlay
    Overlay.Show("x" vx " y" vy " w" vw " h" vh " NoActivate")
}

EnsurePinned() {
    if !(Overlay && PinWindowProc && IsPinnedWindowProc)
        return false
    if (DllCall(IsPinnedWindowProc, "Ptr", Overlay.Hwnd, "Int") = 1)
        return true
    ; Windows needs a moment after the window first appears before it can be pinned.
    start := A_TickCount
    Loop {
        if (DllCall(PinWindowProc, "Ptr", Overlay.Hwnd, "Int") = 1)
            return true
        if (A_TickCount - start > 250)
            return false
        Sleep 10
    }
}

PrepareOverlay() {
    if !(VDA && FADE_ENABLED)
        return
    ShowOverlay(1, 0)
    EnsurePinned()
    Overlay.Hide()
}
PrepareOverlay()

Fade(overlay, from, to, ms) {
    ; 1 ms timer resolution so frames land evenly instead of in ~15 ms chunks.
    DllCall("winmm\timeBeginPeriod", "UInt", 1)
    start := A_TickCount
    Loop {
        t := Min(1, (A_TickCount - start) / ms)
        eased := t < 0.5 ? 4 * t ** 3 : 1 - ((-2 * t + 2) ** 3) / 2
        WinSetTransparent Round(from + (to - from) * eased), overlay
        if (t >= 1)
            break
        Sleep 8
    }
    DllCall("winmm\timeEndPeriod", "UInt", 1)
}

StepToDesktop(target) {
    info := GetDesktopInfo()
    if !info
        return
    if (target > info.count)
        target := info.count
    diff := target - info.current
    if (diff = 0)
        return
    key := diff > 0 ? "Right" : "Left"
    SetKeyDelay 30, 10
    Loop Abs(diff)
        SendEvent "^#{" key "}"
}

GetDesktopInfo() {
    base := "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"
    try ids := RegRead(base "\VirtualDesktops", "VirtualDesktopIDs")
    catch
        return 0

    ; Windows 11 stores the current desktop here; Windows 10 uses SessionInfo.
    current := ""
    try current := RegRead(base "\VirtualDesktops", "CurrentVirtualDesktop")
    if (current = "") {
        DllCall("ProcessIdToSessionId", "UInt", DllCall("GetCurrentProcessId"), "UInt*", &sid := 0)
        try current := RegRead(base "\SessionInfo\" sid "\VirtualDesktops", "CurrentVirtualDesktop")
    }

    count := StrLen(ids) // 32
    if (count = 0)
        return 0
    idx := 1
    if (current != "") {
        pos := InStr(ids, current)
        if (pos)
            idx := (pos - 1) // 32 + 1
    }
    return {current: idx, count: count}
}
