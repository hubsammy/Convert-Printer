Set objFSO = CreateObject("Scripting.FileSystemObject")
strDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """" & strDir & "\build\windows\x64\runner\Release\ConvertPrinter.exe" & """", 1, False
