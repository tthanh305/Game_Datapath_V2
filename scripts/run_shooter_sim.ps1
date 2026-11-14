param(
    [string]$VivadoBin = 'D:\vivado\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runDir = Join-Path $projectRoot 'verification\shooter_sim'
$rtlDir = Join-Path $projectRoot 'rtl\game'
$testbench = Join-Path $projectRoot 'sim\tb_shooter.sv'
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $rtlDir 'sprites_32x32.mem') -Destination $runDir -Force

function Invoke-XsimTool {
    param([string]$ToolName, [string[]]$ToolArguments)
    $toolPath = Join-Path $VivadoBin "$ToolName.bat"
    if (!(Test-Path -LiteralPath $toolPath)) { throw "Tool not found: $toolPath" }
    & $toolPath @ToolArguments
    if ($LASTEXITCODE -ne 0) { throw "$ToolName failed with exit code $LASTEXITCODE" }
}

Push-Location $runDir
try {
    $rtlFiles = (Get-ChildItem (Join-Path $rtlDir '*.v')).FullName
    Invoke-XsimTool 'xvlog' (@('--sv', '--work', 'xil_defaultlib', '--include', $rtlDir) + $rtlFiles + @($testbench, '--log', 'xvlog.log'))
    Invoke-XsimTool 'xelab' @('xil_defaultlib.tb_shooter', '--snapshot', 'tb_shooter_sim', '--debug', 'typical', '--log', 'xelab.log')
    Invoke-XsimTool 'xsim' @('tb_shooter_sim', '--runall', '--log', 'xsim.log')

    $log = Get-Content -LiteralPath 'xsim.log' -Raw
    if ($log -notmatch 'PASS: tb_shooter all (\d+) verification checks succeeded!' -or
        $log -match '(?im)^\s*(FAIL:|FATAL:|ERROR:|Fatal:)') {
        throw 'Simulation did not pass all checks. See xsim.log.'
    }
    $nChecks = $Matches[1]
    Write-Output "VERIFIED: tb_shooter PASS ($nChecks/$nChecks checks). Log: $runDir\xsim.log"
} finally {
    Pop-Location
}
