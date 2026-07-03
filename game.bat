@echo off
rem Gnome Colony - debug launcher for testing (Windows).
rem Launches the playtest slice, the current playable build (the final
rem orchestrated main scene is still a thin stub - see DONE.md #3).
rem Needs Godot 4.7 on PATH, or set GODOT to your editor executable:
rem   set GODOT=C:\path\to\Godot_v4.7-stable_win64.exe

setlocal
if "%GODOT%"=="" set GODOT=godot
"%GODOT%" -d --verbose --path "%~dp0" res://presentation/playtest/playtest_slice.tscn %*
endlocal
