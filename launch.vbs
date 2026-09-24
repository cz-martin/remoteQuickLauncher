Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Zjištění složky, ve které se nachází tento VBS skript
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

' Spuštění PowerShellu bez okna (hodnota 0)
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptDir & "\RemoteLauncher.ps1""", 0, False