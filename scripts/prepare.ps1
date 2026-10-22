<#
  检查安装条件；默认只读，不启动软件或打开链接。
  -InstallNexus：缺少 Nexus 时用 winget 安装，并启动一次等待初始化。
  退出码：0 全部就绪；2 需要用户处理；1 检查或安装出错。
#>
param([switch]$InstallNexus)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
$rows = [System.Collections.Generic.List[object]]::new()
$failed = $false
try {
    $nexus = Find-Nexus
    if (-not $nexus -and $InstallNexus) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw '找不到 winget，请先安装 App Installer 或自行安装 Nexus。'
        }
        & winget install --id WinStep.Nexus -e --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "winget 安装失败，退出码：$LASTEXITCODE" }
        $nexus = Find-Nexus
    }
    $docksKey = 'HKCU:\Software\WinSTEP2000\NeXuS\Docks'
    if ($nexus -and -not (Test-Path $docksKey) -and $InstallNexus) {
        Write-Host '首次需要打开一次 Nexus；正在启动，最多等待 60 秒。请由用户处理首次运行提示。'
        Start-Process -FilePath $nexus
        $deadline = (Get-Date).AddSeconds(60)
        while (-not (Test-Path $docksKey) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
    }
    $ready = $nexus -and (Test-Path $docksKey)
    $detail = if (-not $nexus) { '未安装；自行安装或运行 prepare.ps1 -InstallNexus' }
        elseif (-not $ready) { '配置尚未初始化或等待超时；请用户打开一次 Nexus，等 Dock 出现后重新检查。' }
        else { $nexus }
    $rows.Add([pscustomobject]@{ 项目 = 'Nexus'; 就绪 = [bool]$ready; 说明 = $detail })
} catch {
    $failed = $true
    $rows.Add([pscustomobject]@{ 项目 = 'Nexus'; 就绪 = $false; 说明 = $_.Exception.Message })
}
try {
    $we = Find-WallpaperEngine
    $detail = if ($we) { $we } else {
        '未安装：steam://store/431960；需要用户自己购买。若已购买未安装，请打开 steam://install/431960。'
    }
    $rows.Add([pscustomobject]@{ 项目 = 'Wallpaper Engine'; 就绪 = [bool]$we; 说明 = $detail })
} catch {
    $failed = $true
    $rows.Add([pscustomobject]@{ 项目 = 'Wallpaper Engine'; 就绪 = $false; 说明 = $_.Exception.Message })
}
Write-Host "`n== 准备结果 =="
$rows | Format-Table -AutoSize -Wrap
Write-Host '购买、登录、付款和 Steam 订阅必须由用户亲自完成；本脚本不判断购买状态。'
if ($failed) { exit 1 }
if ($rows | Where-Object { -not $_.就绪 }) { exit 2 }
exit 0
