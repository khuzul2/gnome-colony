@echo off
rem Gnome Colony - game launcher (Windows). Launches the real game: the project
rem main scene (res://presentation/main.tscn) boots the Main Menu -> New Game ->
rem the playable run. Uses the project-local Godot 4.7 by default (no PATH needed);
rem override with:  set GODOT=C:\path\to\Godot_v4.7-stable_win64.exe
setlocal
set "HERE=%~dp0"
if "%GODOT%"=="" set "GODOT=%HERE%godot\Godot_v4.7-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=godot"
rem No scene argument -> Godot runs project.godot's main_scene (the real game),
rem not the old playtest slice. The trailing "." on the project path avoids the
rem batch trailing-backslash-quote bug ("...\" would escape the closing quote).
start "Gnome Colony" "%GODOT%" --path "%HERE%." %*
endlocal
