@echo off
if exist "%~dp0..\Godot_v4.7.2-stable_win64.exe" (
	start "" "%~dp0..\Godot_v4.7.2-stable_win64.exe" --path "%~dp0the-amazing-digital-circus"
	exit /b 0
)
if exist "%~dp0Godot_v4.7.2-stable_win64.exe" (
	start "" "%~dp0Godot_v4.7.2-stable_win64.exe" --path "%~dp0the-amazing-digital-circus"
	exit /b 0
)
echo Put Godot 4.7 next to this folder, then run this again.
echo The file name is Godot_v4.7.2-stable_win64.exe
pause
