<#
  export-nexus.ps1
  把当前 Nexus Dock 的外观设置导出成 config\nexus-dock.json，方便分享给别人。

  只导出主题和 Dock 外观（图标大小、放大效果、倒影、字体等），
  不导出 Dock 上的软件图标、天气城市、邮箱、安装日期这类个人信息。

  用法：
    .\export-nexus.ps1
#>

$ErrorActionPreference = 'Stop'
$nexusKey = 'HKCU:\Software\WinSTEP2000\NeXuS'
$docksKey = "$nexusKey\Docks"
$outFile  = Join-Path $PSScriptRoot '..\config\nexus-dock.json'

if (-not (Test-Path $docksKey)) { Write-Host '没有找到 Nexus 的配置，请先运行一次 Nexus。'; exit 1 }

# 跟屏幕分辨率或这台电脑绑定的设置，不导出
$skip = 'DockPosX1', 'DockPosY1', 'DockEnabledPosX1', 'DockEnabledPosY1', 'DockNSID1', 'DockName1'

$docks = Get-Item $docksKey
$dock = [ordered]@{}
foreach ($name in $docks.GetValueNames() | Sort-Object) {
    if ($name -match '^Dock.*1$' -and $name -notin $skip) { $dock[$name] = $docks.GetValue($name) }
}

$nexus = Get-Item $nexusKey
$theme = [ordered]@{}
foreach ($name in $nexus.GetValueNames() | Sort-Object) {
    if ($name -match '^NeXuS') { $theme[$name] = $nexus.GetValue($name) }
}

# 设置里出现你的个人文件夹路径（C:\Users\你的用户名），说明混进了个人信息，停下来不导出。
# 这只是防止明显的个人路径外泄，导出后最好再自己看一眼 json。
$all = ($dock.Values + $theme.Values) -join "`n"
if ($all.IndexOf($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
    Write-Host "导出内容里含有你的个人文件夹路径 $env:USERPROFILE，已停止。请检查主题是否装在个人文件夹里。"
    exit 1
}

New-Item -ItemType Directory -Force (Split-Path $outFile) | Out-Null
[ordered]@{ theme = $theme; dock = $dock } | ConvertTo-Json -Depth 3 | Set-Content $outFile -Encoding UTF8
Write-Host "已导出 $($theme.Count) 项主题设置和 $($dock.Count) 项 Dock 设置到 $outFile"
