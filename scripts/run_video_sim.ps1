param(
    [string]$VivadoBin = 'D:\vivado\Vivado\2024.2\bin',
    [ValidateSet('All','Unit','Integration')][string]$Suite = 'All'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$gameRtl = Join-Path $projectRoot 'rtl\game'
$videoRtl = Join-Path $projectRoot 'rtl\video'
$syncgen = Join-Path $projectRoot 'Game_Datapath_V2.srcs\sources_1\imports\hdmi_axi_src_720p\rtl\syncgen_multi.v'
if (!(Test-Path -LiteralPath $syncgen)) {
    $syncgen = Join-Path $projectRoot 'verification\video_integration\syncgen_multi_reference.v'
}
if (!(Test-Path -LiteralPath $syncgen)) { throw 'Verified syncgen_multi source is missing' }

function Invoke-XsimTool {
    param([string]$ToolName, [string[]]$ToolArguments)
    $toolPath = Join-Path $VivadoBin "$ToolName.bat"
    if (!(Test-Path -LiteralPath $toolPath)) { throw "Tool not found: $toolPath" }
    & $toolPath @ToolArguments
    if ($LASTEXITCODE -ne 0) { throw "$ToolName failed with exit code $LASTEXITCODE" }
}

$unitRtl = @((Join-Path $videoRtl 'game_clock_reset.v'),(Join-Path $videoRtl 'frame_tick.v'))
$tests = @()
if ($Suite -in @('All','Unit')) {
    $tests += @{Name='video_unit'; Top='tb_video_unit'; Rtl=$unitRtl}
}
if ($Suite -in @('All','Integration')) {
    $fullRtl = @('physics_engine.v','game_hud.v','color_mapper.v','datapath.v',
                 'auto_game_controller.v','game_core.v',
                 'game_button_input.v','game_control_path.v','font_rom.v','game_menu_renderer.v',
                 'game_buzzer.v','galaxian_starfield.v','sprite_rom_bank.v',
                 'space_bg_stereden.v','sprite_rom_32x32.v') | ForEach-Object { Join-Path $gameRtl $_ }
    $fullRtl = @($fullRtl) + $unitRtl + @((Join-Path $videoRtl 'game_video.v'),
        (Join-Path $videoRtl 'pattern_multi.v'),$syncgen,
        (Join-Path $projectRoot 'sim\models\pckgen_triple_model.v'))
    $tests += @{Name='video_integration'; Top='tb_video_integration'; Rtl=$fullRtl}
}
foreach ($test in $tests) {
    $runDir = Join-Path $projectRoot ('verification\' + $test.Name)
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $gameRtl 'sprites_32x32.mem') -Destination $runDir -Force
    Push-Location $runDir
    try {
        Invoke-XsimTool 'xvlog' (@('--work','xil_defaultlib','--include',$gameRtl) +
            $test.Rtl + @('--log','xvlog_rtl.log'))
        Invoke-XsimTool 'xvlog' @('--sv','--work','xil_defaultlib','--include',$gameRtl,
            (Join-Path $projectRoot ('sim\' + $test.Top + '.sv')),'--log','xvlog_tb.log')
        $glbl = Join-Path (Split-Path -Parent $VivadoBin) 'data\verilog\src\glbl.v'
        if (Test-Path -LiteralPath $glbl) {
            Invoke-XsimTool 'xvlog' @('--work','xil_defaultlib',$glbl,'--log','xvlog_glbl.log')
        }
        $snapshot = $test.Name + '_tb'
        $xelabArgs = @(('xil_defaultlib.' + $test.Top),'--snapshot',$snapshot,'-L','xpm','--debug','typical','--log','xelab.log')
        if (Test-Path -LiteralPath $glbl) {
            $xelabArgs = @(('xil_defaultlib.' + $test.Top),'xil_defaultlib.glbl','--snapshot',$snapshot,'-L','xpm','--debug','typical','--log','xelab.log')
        }
        Invoke-XsimTool 'xelab' $xelabArgs
        Invoke-XsimTool 'xsim' @($snapshot,'--runall','--log','xsim.log')
        $log = Get-Content -LiteralPath 'xsim.log' -Raw
        $passMarker = 'PASS: ' + $test.Top + ' checks='
        if (!$log.Contains($passMarker) -or $log -match '(?m)^\s*(FAIL:|FATAL:|ERROR:)') {
            throw "Simulation did not finish with $passMarker. See $runDir\xsim.log."
        }
        Write-Output "VERIFIED: $($test.Top) simulation PASS. Log: $runDir\xsim.log"
    } finally { Pop-Location }
}
