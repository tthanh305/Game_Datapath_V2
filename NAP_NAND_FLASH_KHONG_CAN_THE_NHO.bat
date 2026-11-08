@echo off
setlocal
title Nap BOOT.BIN vao NAND Flash tren mach EBAZ4205 (Khong can the nho SD)
cd /d "%~dp0"

echo ============================================================================
echo   NAP GAME VAO CHIP NHO NAND FLASH (nand-x8) TREN BO MACH EBAZ4205
echo ============================================================================
echo.
echo Dam bao mach da cap nguon va cam cap JTAG.
echo Neu Vivado Hardware Manager dang mo, hay dong Target hoac tat Vivado truoc.
echo.

set "BOOT_BIN=%~dp0BOOT.BIN"
set "FSBL_ELF=%~dp0vitis_game_v2\platformgame_platform_v2\export\platformgame_platform_v2\sw\boot\fsbl.elf"

where program_flash >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    program_flash -f "%BOOT_BIN%" -offset 0 -flash_type nand-x8 -fsbl "%FSBL_ELF%" -verify
    goto :done
)

if defined XILINX_VITIS if exist "%XILINX_VITIS%\bin\program_flash.bat" (
    call "%XILINX_VITIS%\bin\program_flash.bat" -f "%BOOT_BIN%" -offset 0 -flash_type nand-x8 -fsbl "%FSBL_ELF%" -verify
    goto :done
)

for %%P in ("C:\Xilinx\Vitis\2024.2\bin\program_flash.bat" "D:\vivado\Vitis\2024.2\bin\program_flash.bat" "D:\Xilinx\Vitis\2024.2\bin\program_flash.bat") do (
    if exist %%P (
        call %%P -f "%BOOT_BIN%" -offset 0 -flash_type nand-x8 -fsbl "%FSBL_ELF%" -verify
        goto :done
    )
)

echo [ERROR] Khong tim thay program_flash.bat. Hay them Vitis/Vivado bin vao PATH hoac dat bien XILINX_VITIS.
goto :end

:done
echo.
echo ============================================================================
echo Hoan tat! Hay rut cap JTAG (hoac chuyen jumper Boot sang NAND) va cap nguon lai.
echo ============================================================================
:end
pause
