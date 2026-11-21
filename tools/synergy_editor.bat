@echo off
rem Synergy editor: the synergy effects of each season (data/season_synergies.json). See docs/SEASON_SYNERGIES.md.
rem Set GODOT to another Godot 4.7 executable if yours is elsewhere.
setlocal
if "%GODOT%"=="" set "GODOT=C:\Users\nqloc\godot-android\Godot_v4.7-stable_win64.exe"
start "" "%GODOT%" --path "%~dp0.." res://tools/synergy_editor/synergy_editor.tscn %*
