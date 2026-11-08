@echo off
setlocal
title Chay Game Galaxian 720p qua JTAG (EBAZ4205)
cd /d "%~dp0"

echo ============================================================================
echo   NAP BITSTREAM + KHOI TAO ARM PS7 + CHAY GAME QUA JTAG
echo ============================================================================

where xsdb >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    xsdb "%~dp0scripts\program_jtag.tcl"
    goto :end
)

if defined XILINX_VITIS if exist "%XILINX_VITIS%\bin\xsdb.bat" (
    call "%XILINX_VITIS%\bin\xsdb.bat" "%~dp0scripts\program_jtag.tcl"
    goto :end
)

for %%P in ("C:\Xilinx\Vitis\2024.2\bin\xsdb.bat" "D:\vivado\Vitis\2024.2\bin\xsdb.bat" "D:\Xilinx\Vitis\2024.2\bin\xsdb.bat") do (
    if exist %%P (
        call %%P "%~dp0scripts\program_jtag.tcl"
        goto :end
    )
)

echo [ERROR] Khong tim thay xsdb.bat. Hay them Vitis/Vivado bin vao PATH hoac dat bien XILINX_VITIS.
:end
pause
