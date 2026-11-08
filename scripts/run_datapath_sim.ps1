param(
    [string]$VivadoBin = 'D:\vivado\Vivado\2024.2\bin',
    [ValidateSet('All','Renderer','Datapath')][string]$Suite = 'All'
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
if ($Suite -in @('All','Renderer')) {
    $tests += @{Name='color_mapper'; Top='tb_color_mapper';
        Rtl=@('game_hud.v','galaxian_starfield.v','galaxian_sprites.v','explosion_particles.v','color_mapper.v'); ExportImages=$true}
}
if ($Suite -in @('All','Datapath')) {
    $tests += @{Name='datapath'; Top='tb_datapath';
        Rtl=@('physics_engine.v','game_hud.v','galaxian_starfield.v','galaxian_sprites.v','explosion_particles.v','color_mapper.v','datapath.v'); ExportImages=$false}
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
        $simArguments = @($snapshot,'--runall','--log','xsim.log')
        if ($test.ExportImages) { $simArguments += @('--testplusarg','EXPORT_IMAGES') }
        Invoke-XsimTool 'xsim' $simArguments
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
