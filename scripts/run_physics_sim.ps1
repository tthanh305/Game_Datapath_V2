param(
    [string]$VivadoBin = 'D:\vivado\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runDir = Join-Path $projectRoot 'verification\physics_engine'
$rtlDir = Join-Path $projectRoot 'rtl\game'
$testbench = Join-Path $projectRoot 'sim\tb_physics_engine.sv'
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

function Invoke-XsimTool {
    param([string]$ToolName, [string[]]$ToolArguments)
    $toolPath = Join-Path $VivadoBin "$ToolName.bat"
    if (!(Test-Path -LiteralPath $toolPath)) { throw "Tool not found: $toolPath" }
    & $toolPath @ToolArguments
    if ($LASTEXITCODE -ne 0) { throw "$ToolName failed with exit code $LASTEXITCODE" }
}

Push-Location $runDir
try {
    Invoke-XsimTool 'xvlog' @('--work', 'xil_defaultlib', '--include', $rtlDir,
        (Join-Path $rtlDir 'physics_engine.v'), '--log', 'xvlog_rtl.log')
    Invoke-XsimTool 'xvlog' @('--sv', '--work', 'xil_defaultlib', '--include', $rtlDir,
        $testbench, '--log', 'xvlog_tb.log')
    Invoke-XsimTool 'xelab' @('xil_defaultlib.tb_physics_engine', '--snapshot',
        'physics_engine_tb', '--debug', 'typical', '--log', 'xelab.log')
    Invoke-XsimTool 'xsim' @('physics_engine_tb', '--runall', '--log', 'xsim.log')

    $log = Get-Content -LiteralPath 'xsim.log' -Raw
    if ($log -notmatch 'PASS: tb_physics_engine checks=' -or
        $log -match '(?m)^\s*(FAIL:|FATAL:|ERROR:)') {
        throw 'Simulation did not finish with the expected PASS marker. See xsim.log.'
    }
    Write-Output "VERIFIED: Physics Engine simulation PASS. Log: $runDir\xsim.log"
} finally {
    Pop-Location
}
