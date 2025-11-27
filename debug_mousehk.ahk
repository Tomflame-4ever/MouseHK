#Requires AutoHotkey v2.0
IniFile := A_ScriptDir "\MouseHK.ini"
if !FileExist(IniFile) {
    FileAppend "INI File NOT FOUND`n", "debug_log.txt"
    ExitApp
}

val := IniRead(IniFile, "Controls", "Right", "ERROR")
FileAppend "Raw Value: " val "`n", "debug_log.txt"

parts := StrSplit(val, "|")
for k, v in parts {
    FileAppend "Key " k ": " v " (Len: " StrLen(v) ") - Asc: " Ord(v) "`n", "debug_log.txt"
}
