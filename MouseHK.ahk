; ========================================================================================
;  MouseHK (v1.1 - Zero Lag Edition)
;  Created by Tomflame with help from Google Antigravity
;  Refactored with Delta Time & Kernel Injection for smoother scrolling
; ========================================================================================

global Config := Map()
global IniFile := A_ScriptDir "\MouseHK.ini"

LoadConfig() {
    global Config, IniFile

    ; --- Valores por Defecto (Hardcoded User Config) ---
    Config["BaseSpeed"] := 2
    Config["MaxSpeed"] := 35
    Config["Acceleration"] := 1.5
    Config["PrecisionSpeed"] := 4
    Config["ScrollDelay"] := 6
    Config["SuppressKeys"] := 1
    Config["StartActive"] := 0

    ; Controles (Arrays de teclas)
    Config["Up"] := ["W", "O"]
    Config["Down"] := ["S", "L"]
    Config["Left"] := ["A", "K"]
    Config["Right"] := ["D", ";", "Ñ"]
    Config["LeftClick"] := ["E", "I"]
    Config["RightClick"] := ["Q", "P"]
    Config["MiddleClick"] := ["F", "J"]
    Config["Button4"] := []
    Config["Button5"] := []

    ; Default Unified Hotkeys
    Config["ToggleMouse"] := ["+Space"] ; Shift + Space
    Config["PrecisionMode"] := ["Shift"]
    Config["ScrollMode"] := ["Space"]
    Config["ClickHolder"] := ["Shift"]
    Config["ReloadScript"] := ["*^+!#F5"]
    Config["LockTriggers"] := []

    ; --- Leer INI si existe ---
    if FileExist(IniFile) {
        try {
            ; Options
            Config["SuppressKeys"] := IniRead(IniFile, "Options", "SuppressKeys", Config["SuppressKeys"])
            Config["StartActive"] := IniRead(IniFile, "Options", "StartActive", Config["StartActive"])

            ; Movement
            Config["BaseSpeed"] := IniRead(IniFile, "Movement", "BaseSpeed", Config["BaseSpeed"])
            Config["MaxSpeed"] := IniRead(IniFile, "Movement", "MaxSpeed", Config["MaxSpeed"])
            Config["Acceleration"] := IniRead(IniFile, "Movement", "Acceleration", Config["Acceleration"])
            Config["PrecisionSpeed"] := IniRead(IniFile, "Movement", "PrecisionSpeed", Config["PrecisionSpeed"])

            ; Scroll
            Config["ScrollDelay"] := IniRead(IniFile, "Scroll", "ScrollDelay", Config["ScrollDelay"])

            ; Controls (Parse pipe-separated values)
            Config["Up"] := StrSplit(IniRead(IniFile, "Controls", "Up", "Numpad8"), "|")
            Config["Down"] := StrSplit(IniRead(IniFile, "Controls", "Down", "Numpad5"), "|")
            Config["Left"] := StrSplit(IniRead(IniFile, "Controls", "Left", "Numpad4"), "|")
            Config["Right"] := StrSplit(IniRead(IniFile, "Controls", "Right", "Numpad6"), "|")
            Config["LeftClick"] := StrSplit(IniRead(IniFile, "Controls", "LeftClick", "Numpad7"), "|")
            Config["RightClick"] := StrSplit(IniRead(IniFile, "Controls", "RightClick", "Numpad9"), "|")
            Config["MiddleClick"] := StrSplit(IniRead(IniFile, "Controls", "MiddleClick", "NumpadDiv"), "|")
            Config["Button4"] := StrSplit(IniRead(IniFile, "Controls", "Button4", ""), "|")
            Config["Button5"] := StrSplit(IniRead(IniFile, "Controls", "Button5", ""), "|")

            ; Behavior Modifiers
            Config["PrecisionMode"] := ParseUnifiedHotkey(IniRead(IniFile, "BehaviorModifiers", "PrecisionMode", "Shift"))
            Config["ScrollMode"] := ParseUnifiedHotkey(IniRead(IniFile, "BehaviorModifiers", "ScrollMode", "Space"))
            Config["ClickHolder"] := ParseUnifiedHotkey(IniRead(IniFile, "BehaviorModifiers", "ClickHolder", "Numpad0"))

            ; Hotkeys (Unified Parser)
            rawToggle := IniRead(IniFile, "Hotkeys", "ToggleMouse", "Shift + Space")
            parsedToggle := ParseUnifiedHotkey(rawToggle)

            ; Separate standard hotkeys from Lock Triggers
            Config["ToggleMouse"] := []
            Config["LockTriggers"] := []

            for item in parsedToggle {
                if (IsLockTrigger(item)) {
                    Config["LockTriggers"].Push(ParseLockTrigger(item))
                } else {
                    Config["ToggleMouse"].Push(item)
                }
            }

            Config["ReloadScript"] := ParseUnifiedHotkey(IniRead(IniFile, "Hotkeys", "ReloadScript", "Ctrl + Shift + Alt + Win + F5"))
        }
    }
}

LoadConfig()

; ========================================================================================
;  VARIABLES GLOBALES
; ========================================================================================

; --- Parámetros de Movimiento (desde Config) ---
global BaseSpeed := Config["BaseSpeed"]
global MaxSpeed := Config["MaxSpeed"]
global Acceleration := Config["Acceleration"]
global PrecisionSpeed := Config["PrecisionSpeed"]
global ScrollDelay := Config["ScrollDelay"]

; --- Estado Interno ---
global CurrentSpeedX := 0
global CurrentSpeedY := 0
global HeldKeys := Map()

; NUEVAS VARIABLES PARA DELTA TIME SCROLLING
global ScrollDuration := 0
global LastScrollTime := 0

; --- Listas de Teclas Usadas ---
global UsedKeys := Map()

; ========================================================================================
;  INICIALIZACIÓN
; ========================================================================================

; Iniciar suspendido o activo según config
if (Config["StartActive"]) {
    Suspend False
    SyncLockKeys(true)
} else {
    Suspend True
    SyncLockKeys(false)
}

; ========================================================================================
;  HELPER FUNCTIONS (PARSER)
; ========================================================================================

ParseUnifiedHotkey(str) {
    result := []
    parts := StrSplit(str, "|")

    for part in parts {
        part := Trim(part)
        if (part == "")
            continue

        keys := StrSplit(part, "+")
        modifiers := ""
        mainKeys := []

        for k in keys {
            k := Trim(k)
            if (k == "")
                continue

            switch StrLower(k) {
                case "ctrl", "control": modifiers .= "^"
                case "shift": modifiers .= "+"
                case "alt": modifiers .= "!"
                case "win", "windows": modifiers .= "#"
                default: mainKeys.Push(k)
            }
        }

        ahkString := ""
        if (mainKeys.Length == 0) {
            if (modifiers != "") {
                ahkString := modifiers
            }
        } else if (mainKeys.Length == 1) {
            ahkString := modifiers . mainKeys[1]
        } else {
            ahkString := modifiers . mainKeys[1] . " & " . mainKeys[2]
        }

        result.Push(ahkString)
    }
    return result
}

IsLockTrigger(str) {
    str := StrUpper(Trim(str))
    return (InStr(str, "CAPSLOCK") || InStr(str, "NUMLOCK") || InStr(str, "SCROLLLOCK")) && (InStr(str, " ON") || InStr(str, " OFF"))
}

ParseLockTrigger(str) {
    str := StrUpper(Trim(str))
    key := ""
    state := 0 ; 0=OFF, 1=ON

    if (InStr(str, "CAPSLOCK"))
        key := "CapsLock"
    else if (InStr(str, "NUMLOCK"))
        key := "NumLock"
    else if (InStr(str, "SCROLLLOCK"))
        key := "ScrollLock"

    if (InStr(str, " ON"))
        state := 1

    return { Key: key, State: state }
}

IsHotkeyPressed(ahkList) {
    for hotkeyStr in ahkList {
        if (CheckSingleHotkeyState(hotkeyStr))
            return true
    }
    return false
}

CheckSingleHotkeyState(hotkeyStr) {
    hotkeyStr := StrReplace(hotkeyStr, "*", "")
    hotkeyStr := StrReplace(hotkeyStr, "~", "")
    hotkeyStr := StrReplace(hotkeyStr, "$", "")

    if (InStr(hotkeyStr, "&")) {
        parts := StrSplit(hotkeyStr, "&")
        key1 := Trim(parts[1])
        key2 := Trim(parts[2])
        if (!CheckModifiers(key1, &cleanKey1))
            return false
        return GetKeyState(cleanKey1, "P") && GetKeyState(key2, "P")
    }

    if (!CheckModifiers(hotkeyStr, &cleanKey))
        return false

    if (cleanKey == "")
        return true

    try {
        return GetKeyState(cleanKey, "P")
    } catch {
        return false
    }
}

CheckModifiers(str, &cleanKey) {
    cleanKey := str
    if (InStr(str, "^")) {
        if (!GetKeyState("Ctrl", "P"))
            return false
        cleanKey := StrReplace(cleanKey, "^", "")
    }
    if (InStr(str, "+")) {
        if (!GetKeyState("Shift", "P"))
            return false
        cleanKey := StrReplace(cleanKey, "+", "")
    }
    if (InStr(str, "!")) {
        if (!GetKeyState("Alt", "P"))
            return false
        cleanKey := StrReplace(cleanKey, "!", "")
    }
    if (InStr(str, "#")) {
        if (!GetKeyState("LWin", "P") && !GetKeyState("RWin", "P"))
            return false
        cleanKey := StrReplace(cleanKey, "#", "")
    }
    return true
}

; ========================================================================================
;  HOTKEYS DE SISTEMA
; ========================================================================================

#SuspendExempt

; --- Reinicio de Emergencia ---
for hk in Config["ReloadScript"] {
    try Hotkey "*" . hk, (*) => Reload(), "S"
}

; --- Activación / Desactivación ---
SetupToggleHotkeys() {
    for hk in Config["ToggleMouse"] {
        try Hotkey "*" . hk, ToggleSuspendAction, "S"
    }
    SetupLockTriggers()
}

SetupLockTriggers() {
    for trigger in Config["LockTriggers"] {
        try Hotkey "~*" . trigger.Key, CheckLockState, "S"
    }
    CheckLockState()
}

CheckLockState(*) {
    if (Config["LockTriggers"].Length == 0)
        return

    shouldBeActive := false

    for trigger in Config["LockTriggers"] {
        currentState := GetKeyState(trigger.Key, "T") 
        if (currentState == trigger.State) {
            shouldBeActive := true
            break
        }
    }

    if (shouldBeActive) {
        if (A_IsSuspended)
            SetSuspendState(true) 
    } else {
        if (!A_IsSuspended)
            SetSuspendState(false) 
    }
}

ToggleSuspendAction(ThisHotkey) {
    ToggleSuspend()
}

SyncLockKeys(active) {
    for trigger in Config["LockTriggers"] {
        targetState := active ? trigger.State : !trigger.State
        stateStr := targetState ? "On" : "Off"

        if (trigger.Key = "CapsLock")
            SetCapsLockState stateStr
        else if (trigger.Key = "NumLock")
            SetNumLockState stateStr
        else if (trigger.Key = "ScrollLock")
            SetScrollLockState stateStr
    }
}

#SuspendExempt False

; ========================================================================================
;  FUNCIONES DE CONTROL DE ESTADO
; ========================================================================================

ToggleSuspend() {
    SetSuspendState(A_IsSuspended)
}

SetSuspendState(makeActive) {
    if (makeActive) {
        ; --- ACTIVAR (Suspend False) ---
        Suspend False
        SoundBeep 1000, 200
        SyncLockKeys(true)
    } else {
        ; --- DESACTIVAR (Suspend True) ---
        Suspend True
        ClearState()
        SoundBeep 500, 200
        SyncLockKeys(false)
    }
}

ClearState() {
    global HeldKeys, CurrentSpeedX, CurrentSpeedY
    global ScrollDuration, LastScrollTime

    HeldKeys.Clear()
    CurrentSpeedX := 0
    CurrentSpeedY := 0
    
    ; Resetear variables de scroll
    ScrollDuration := 0
    LastScrollTime := 0

    if (GetKeyState("LButton"))
        Click "Left Up"
    if (GetKeyState("RButton"))
        Click "Right Up"
    if (GetKeyState("MButton"))
        Click "Middle Up"
}

; ========================================================================================
;  LÓGICA DE SUPRESIÓN INTELIGENTE
; ========================================================================================

IsActiveContext(HotkeyName) {
    return !A_IsSuspended
}

SetupSuppression() {
    if (Config["SuppressKeys"] != 1)
        return

    HotIf IsActiveContext

    ; --- 1. Letras (a-z) ---
    loop 26 {
        char := Chr(96 + A_Index)
        normalized := StrLower(NormalizeKey(char))
        if (!UsedKeys.Has(normalized))
            Hotkey char, SuppressAction
    }

    ; --- 2. Números (0-9) ---
    loop 10 {
        num := A_Index - 1
        normalized := String(num)
        if (!UsedKeys.Has(normalized))
            Hotkey num, SuppressAction
    }

    ; --- 3. Numpad (Excluyendo Enter, Del) ---
    numpadKeys := ["Numpad0", "Numpad1", "Numpad2", "Numpad3", "Numpad4",
        "Numpad5", "Numpad6", "Numpad7", "Numpad8", "Numpad9",
        "NumpadDiv", "NumpadMult", "NumpadAdd", "NumpadSub", "NumpadDot"]

    for key in numpadKeys {
        normalized := StrLower(NormalizeKey(key))
        if (!UsedKeys.Has(normalized))
            try Hotkey key, SuppressAction
    }

    ; --- 4. Símbolos y Puntuación ---
    extraChars := ["'", "[", "]", "\", "/", "``", "-", ",", ".", ";", "=", "ñ", "ç", "Ç"]
    shiftSymbols := ["!", "`"", "·", "$", "%", "&", "(", ")", "?", "¿", "¡", "*", "+", "_", ":", "<", ">", "|", "@", "#", "^"]

    allSymbols := []
    allSymbols.Push(extraChars*)
    allSymbols.Push(shiftSymbols*)

    for char in allSymbols {
        normalized := StrLower(NormalizeKey(char))
        if (!UsedKeys.Has(normalized)) {
            try Hotkey char, SuppressAction
        }
    }

    HotIf
}

BindFunctionalKeys() {
    HotIf (*) => !A_IsSuspended

    functionalLists := [Config["PrecisionMode"], Config["ScrollMode"], Config["ClickHolder"]]

    for list in functionalLists {
        for hk in list {
            baseKey := ExtractBaseKey(hk)
            if (baseKey != "" && !IsPureModifier(baseKey)) {
                normalized := StrLower(NormalizeKey(baseKey))
                if (!UsedKeys.Has(normalized)) {
                    try Hotkey "*" . baseKey, SuppressAction
                    try Hotkey "*" . baseKey . " Up", SuppressAction
                    UsedKeys[normalized] := 1
                }
            }
        }
    }

    HotIf
}

ExtractBaseKey(hk) {
    hk := StrReplace(hk, "*", "")
    hk := StrReplace(hk, "~", "")
    hk := StrReplace(hk, "$", "")
    hk := StrReplace(hk, "^", "")
    hk := StrReplace(hk, "+", "")
    hk := StrReplace(hk, "!", "")
    hk := StrReplace(hk, "#", "")

    if (InStr(hk, "&")) {
        parts := StrSplit(hk, "&")
        return Trim(parts[2])
    }

    return Trim(hk)
}

IsPureModifier(key) {
    key := StrLower(key)
    return (key == "ctrl" || key == "shift" || key == "alt" || key == "win"
        || key == "lctrl" || key == "rctrl" || key == "lshift" || key == "rshift"
        || key == "lalt" || key == "ralt" || key == "lwin" || key == "rwin")
}

SuppressAction(ThisHotkey) {
    return
}

; ========================================================================================
;  MOTOR DE MOVIMIENTO (OPTIMIZADO CON DLLCALL + DELTA TIME)
; ========================================================================================

SetTimer MoveCursor, 10

MoveCursor() {
    global CurrentSpeedX, CurrentSpeedY
    global ScrollDuration, LastScrollTime
    global MaxSpeed, Acceleration, PrecisionSpeed

    if (A_IsSuspended)
        return
    
    ; Permitir interrupciones leves para evitar tartamudeo en CPU alta
    Critical "Off"

    TargetX := GetTargetDirection("x")
    TargetY := GetTargetDirection("y")

    PrecisionMode := IsHotkeyPressed(Config["PrecisionMode"])
    ScrollMode := IsHotkeyPressed(Config["ScrollMode"])

    if (ScrollMode) {
        ; --- MODO SCROLL (ZERO LAG) ---
        CurrentSpeedX := 0
        CurrentSpeedY := 0

        if (TargetX != 0 || TargetY != 0) {
            
            currentTime := A_TickCount
            
            ; Inicializar tiempo si es el primer ciclo
            if (LastScrollTime == 0) {
                LastScrollTime := currentTime - 100 
                ScrollDuration := 0
            }

            timeSinceLast := currentTime - LastScrollTime
            
            if (timeSinceLast < 200) {
                 ScrollDuration += timeSinceLast
            }

            ; Calculo de delay dinámico (Aceleración)
            tickEstimate := ScrollDuration / 10
            requiredDelay := (tickEstimate < 40) ? 90 : (tickEstimate < 100) ? 60 : 30

            if (currentTime - LastScrollTime >= requiredDelay) {
                
                ; Inyección directa al Kernel (Evita SendInput Lag)
                
                ; Vertical
                if (TargetY < 0) ; Up
                    DllCall("mouse_event", "UInt", 0x800, "UInt", 0, "UInt", 0, "UInt", 120, "UInt", 0)
                else if (TargetY > 0) ; Down
                    DllCall("mouse_event", "UInt", 0x800, "UInt", 0, "UInt", 0, "UInt", -120, "UInt", 0)
                
                ; Horizontal
                if (TargetX < 0) ; Left
                    DllCall("mouse_event", "UInt", 0x1000, "UInt", 0, "UInt", 0, "UInt", -120, "UInt", 0)
                else if (TargetX > 0) ; Right
                    DllCall("mouse_event", "UInt", 0x1000, "UInt", 0, "UInt", 0, "UInt", 120, "UInt", 0)
                
                LastScrollTime := currentTime
            }
        } else {
            ; Resetear aceleración
            ScrollDuration := 0
            LastScrollTime := 0 
        }

    } else {
        ; --- MODO CURSOR ---
        ; Resetear scroll si salimos del modo
        if (ScrollDuration > 0) {
            ScrollDuration := 0
            LastScrollTime := 0
        }

        if (PrecisionMode) {
            CurrentSpeedX := TargetX * PrecisionSpeed
            CurrentSpeedY := TargetY * PrecisionSpeed
        } else {
            ApplyAcceleration("x", TargetX)
            ApplyAcceleration("y", TargetY)
        }

        if (CurrentSpeedX != 0 || CurrentSpeedY != 0) {
            ; Usar DllCall para movimiento (Más ligero que MouseMove)
            DllCall("mouse_event", "UInt", 0x0001, "Int", Round(CurrentSpeedX), "Int", Round(CurrentSpeedY), "UInt", 0, "UInt", 0)
        }
    }
}

ApplyAcceleration(axis, target) {
    global CurrentSpeedX, CurrentSpeedY, MaxSpeed, Acceleration
    speed := (axis == "x") ? CurrentSpeedX : CurrentSpeedY

    if (target != 0) {
        if (speed * target < 0)
            speed := 0
        speed += target * Acceleration
        if (speed > MaxSpeed)
            speed := MaxSpeed
        else if (speed < -MaxSpeed)
            speed := -MaxSpeed
    } else {
        speed := 0
    }

    if (axis == "x")
        CurrentSpeedX := speed
    else
        CurrentSpeedY := speed
}

; --- Gestión de Teclas ---

Press(key, axis, dir, *) {
    global HeldKeys
    if (HeldKeys.Has(key))
        return
    HeldKeys[key] := { axis: axis, dir: dir, time: A_TickCount }
}

Release(key, *) {
    global HeldKeys
    if (HeldKeys.Has(key))
        HeldKeys.Delete(key)
}

GetTargetDirection(axis) {
    global HeldKeys
    latestTime := 0
    target := 0
    for key, info in HeldKeys {
        if (info.axis == axis && info.time > latestTime) {
            target := info.dir
            latestTime := info.time
        }
    }
    return target
}

; ========================================================================================
;  BINDING DINÁMICO DE HOTKEYS
; ========================================================================================

NormalizeKey(key) {
    key := Trim(key)
    if (key = "ñ" || key = "Ñ")
        return "SC027"
    return key
}

GetNumpadVariant(key) {
    static variants := Map(
        "Numpad0", "NumpadIns",
        "Numpad1", "NumpadEnd",
        "Numpad2", "NumpadDown",
        "Numpad3", "NumpadPgDn",
        "Numpad4", "NumpadLeft",
        "Numpad5", "NumpadClear",
        "Numpad6", "NumpadRight",
        "Numpad7", "NumpadHome",
        "Numpad8", "NumpadUp",
        "Numpad9", "NumpadPgUp",
        "NumpadDot", "NumpadDel"
    )
    if (variants.Has(key))
        return variants[key]
    return ""
}

BindMove(key, axis, dir) {
    if (key == "")
        return

    key := NormalizeKey(key)
    UsedKeys[StrLower(key)] := 1

    DoBindMove(key, axis, dir)

    variant := GetNumpadVariant(key)
    if (variant != "") {
        UsedKeys[StrLower(variant)] := 1
        DoBindMove(variant, axis, dir)
    }
}

DoBindMove(key, axis, dir) {
    Hotkey "*$" . key, (ThisHotkey) => Press(key, axis, dir)
    Hotkey "*$" . key . " up", (ThisHotkey) => Release(key)
}

BindClick(key, button) {
    if (key == "")
        return

    key := NormalizeKey(key)
    UsedKeys[StrLower(key)] := 1

    DoBindClick(key, button)

    variant := GetNumpadVariant(key)
    if (variant != "") {
        UsedKeys[StrLower(variant)] := 1
        DoBindClick(variant, button)
    }
}

DoBindClick(key, button) {
    Hotkey "*$" . key, (ThisHotkey) => ClickAction(button)
    Hotkey "*$" . key . " up", (ThisHotkey) => ClickActionUp(button)
}

SetupHotkeys() {
    HotIf IsActiveContext

    ; --- Movimiento ---
    for key in Config["Up"]
        BindMove(key, "y", -1)
    for key in Config["Down"]
        BindMove(key, "y", 1)
    for key in Config["Left"]
        BindMove(key, "x", -1)
    for key in Config["Right"]
        BindMove(key, "x", 1)

    ; --- Clicks ---
    for key in Config["LeftClick"]
        BindClick(key, "Left")
    for key in Config["RightClick"]
        BindClick(key, "Right")
    for key in Config["MiddleClick"]
        BindClick(key, "Middle")
    for key in Config["Button4"]
        BindClick(key, "Button4")
    for key in Config["Button5"]
        BindClick(key, "Button5")

    HotIf
}

; --- Funciones de Click ---

ClickAction(button) {
    btnKey := (button == "Left") ? "LButton" : (button == "Right") ? "RButton" : (button == "Middle") ? "MButton" : (button == "Button4") ? "XButton1" : "XButton2"

    if (IsHotkeyPressed(Config["ClickHolder"])) {
        if (GetKeyState(btnKey))
            SendInput "{Blind}{" btnKey " Up}"
        else
            SendInput "{Blind}{" btnKey " Down}"
    } else {
        SendInput "{Blind}{" btnKey " Down}"
    }
}

ClickActionUp(button) {
    btnKey := (button == "Left") ? "LButton" : (button == "Right") ? "RButton" : (button == "Middle") ? "MButton" : (button == "Button4") ? "XButton1" : "XButton2"

    if (IsHotkeyPressed(Config["ClickHolder"])) {
        return
    }
    SendInput "{Blind}{" btnKey " Up}"
}

#Requires AutoHotkey v2.0
#SingleInstance Force
InstallKeybdHook(true, true)
ProcessSetPriority "High"
SendMode "Input"

SetupHotkeys()
SetupToggleHotkeys()
SetupSuppression()
BindFunctionalKeys()