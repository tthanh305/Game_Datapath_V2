param(
    [string]$VivadoBin = 'D:\vivado\Vivado\2024.2\bin',
    [ValidateSet('All','Controller','Integration')][string]$Suite = 'All'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$rtlDir = Join-Path $projectRoot 'rtl\game'

function Invoke-XsimTool {
    param([string]$ToolName, [string[]]$ToolArguments)
    $toolPath = Join-Path $VivadoBin "$ToolName.bat"
    if (!(Test-Path -LiteralPath $toolPath)) { throw "Tool not found: $toolPath" }
    & $toolPath @ToolArguments
    if ($LASTEXITCODE -ne 0) { throw "$ToolName failed with exit code $LASTEXITCODE" }
}

$tests = @()
if ($Suite -in @('All','Controller')) {
    $tests += @{Name='auto_game_controller'; Top='tb_auto_game_controller';
        Rtl=@('auto_game_controller.v')}
}
if ($Suite -in @('All','Integration')) {
    $tests += @{Name='game_integration'; Top='tb_game_integration';
        Rtl=@('physics_engine.v','game_hud.v','galaxian_starfield.v','galaxian_sprites.v','explosion_particles.v','color_mapper.v','datapath.v',
              'auto_game_controller.v','game_core.v')}
}
foreach ($test in $tests) {
    $runDir = Join-Path $projectRoot ('verification\' + $test.Name)
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    Push-Location $runDir
    try {
        $rtlFiles = @($test.Rtl | ForEach-Object { Join-Path $rtlDir $_ })
        Invoke-XsimTool 'xvlog' (@('--work','xil_defaultlib','--include',$rtlDir) +
            $rtlFiles + @('--log','xvlog_rtl.log'))
        Invoke-XsimTool 'xvlog' @('--sv','--work','xil_defaultlib','--include',$rtlDir,
            (Join-Path $projectRoot ('sim\' + $test.Top + '.sv')),'--log','xvlog_tb.log')
        $snapshot = $test.Name + '_tb'
        Invoke-XsimTool 'xelab' @(('xil_defaultlib.' + $test.Top),'--snapshot',$snapshot,
            '--debug','typical','--log','xelab.log')
        Invoke-XsimTool 'xsim' @($snapshot,'--runall','--log','xsim.log')
        $log = Get-Content -LiteralPath 'xsim.log' -Raw
        $passMarker = 'PASS: ' + $test.Top + ' checks='
        if (!$log.Contains($passMarker) -or $log -match '(?m)^\s*(FAIL:|FATAL:|ERROR:)') {
            throw "Simulation did not finish with $passMarker. See $runDir\xsim.log."
        }
        Write-Output "VERIFIED: $($test.Top) simulation PASS. Log: $runDir\xsim.log"
    } finally {
        Pop-Location
    }
}
