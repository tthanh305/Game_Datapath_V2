# One-click JTAG programming script for EBAZ4205 Galaxian Game
$VitisXsct = "D:\vivado\Vitis\2024.2\bin\xsct.bat"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TclScript = Join-Path $ScriptDir "program_jtag.tcl"

Write-Host "Programming EBAZ4205 via JTAG (Bitstream + PS7 Init + ELF)..." -ForegroundColor Cyan
& $VitisXsct $TclScript

