@echo off
rem Wave editor: wave templates (data/wave_templates.json) and difficulty levels
rem (data/difficulty.json) of the Endless mode. See docs/DIFFICULTY.md.
rem Set GODOT to another Godot 4.7 executable if yours is elsewhere.
setlocal
if "%GODOT%"=="" set "GODOT=C:\Users\nqloc\godot-android\Godot_v4.7-stable_win64.exe"
start "" "%GODOT%" --path "%~dp0.." res://tools/wave_editor/wave_editor.tscn %*
