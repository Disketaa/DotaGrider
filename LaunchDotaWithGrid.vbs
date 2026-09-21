Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

' Run grid generation
sh.Run "powershell -ExecutionPolicy Bypass -NoProfile -File " & chr(34) & scriptDir & "\GenerateHeroGrid.ps1" & chr(34), 0, True

' Build Dota command from remaining arguments
dotaCmd = ""
For i = 0 To WScript.Arguments.Count - 1
    dotaCmd = dotaCmd & " " & chr(34) & WScript.Arguments(i) & chr(34)
Next

' Launch Dota
If dotaCmd <> "" Then
    sh.Run dotaCmd, 1, False
End If
