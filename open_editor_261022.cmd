@echo off
setlocal
if not defined GODOT_ROMANCE_EXE set "GODOT_ROMANCE_EXE=%~dp0..\Game_Edu_step1\.tools\Godot_261021\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_ROMANCE_EXE%" (
    echo Godot was not found. Set GODOT_ROMANCE_EXE or import project.godot from Godot.
    pause
    exit /b 1
)
start "" "%GODOT_ROMANCE_EXE%" --editor --path "%~dp0."
