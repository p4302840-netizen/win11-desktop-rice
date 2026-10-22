<#
  install.ps1
  一键复刻这个桌面。依次做三件事：
    1. 调整任务栏和桌面（深色、自动隐藏、隐藏桌面图标）
    2. 导入 Nexus Dock 的外观，并把检测到的常用软件放上 Dock
    3. 让 Wallpaper Engine 开机稳定自启

  每一步都会先备份，运行 restore.ps1 可以还原。
  某一步失败不会影响其他步骤，最后会列出每一步的结果。

  用法（在本文件夹里打开终端）：
    powershell -ExecutionPolicy Bypass -File .\install.ps1
#>

$scripts = Join-Path $PSScriptRoot 'scripts'
. "$scripts\common.ps1"

$results = [System.Collections.Generic.List[object]]::new()

# 运行一个子脚本，按它的退出码记录成功或失败
function Invoke-Step([string]$name, [string]$script, [hashtable]$scriptArgs = @{}) {
    Write-Host "`n== $name =="
    $global:LASTEXITCODE = 0
    try {
        & "$scripts\$script" @scriptArgs
        $ok = ($LASTEXITCODE -eq 0)
    } catch {
        Write-Host "出错：$($_.Exception.Message)"
        $ok = $false
    }
    $results.Add([pscustomobject]@{ 步骤 = $name; 结果 = $(if ($ok) { '成功' } else { '失败' }) })
}

function Skip-Step([string]$name, [string]$reason) {
    Write-Host "`n== $name =="
    Write-Host "跳过：$reason"
    $results.Add([pscustomobject]@{ 步骤 = $name; 结果 = "跳过（$reason）" })
}

Write-Host '== 检查环境 =='
$weExe    = Find-WallpaperEngine
$nexusExe = Find-Nexus
Write-Host ("Windows：         {0}" -f (Get-CimInstance Win32_OperatingSystem).Caption)
Write-Host ("Wallpaper Engine：{0}" -f $(if ($weExe) { $weExe } else { '未安装（Steam 商店购买：https://store.steampowered.com/app/431960/）' }))
Write-Host ("Nexus Dock：      {0}" -f $(if ($nexusExe) { $nexusExe } else { '未安装（免费下载：https://www.winstep.net/nexus.htm）' }))
if (Get-ScheduledTask -TaskName WallpaperEngine_Logon -ErrorAction SilentlyContinue) {
    Write-Host '已有计划任务 WallpaperEngine_Logon：会先完整备份，还原时恢复原样。'
}

Write-Host "`n接下来会："
Write-Host '  - 把任务栏改成深色并自动隐藏，隐藏桌面图标'
if ($nexusExe) { Write-Host '  - 导入 Nexus Dock 外观，把图标统一成同样大小（下一步会问你要不要保留现有软件）' }
if ($weExe)    { Write-Host '  - 设置 Wallpaper Engine 登录后自动启动' }
Write-Host "每一步都会先备份到 $PSScriptRoot\backup，请不要删除这个文件夹。"

$answer = Read-Host "`n继续吗？(Y/N)"
if ($answer -notmatch '^[Yy]') { Write-Host '已取消，什么都没改。'; exit 0 }

$nexusArgs = @{}
if ($nexusExe) {
    $keep = Read-Host "`n保留你 Dock 上现有的软件，只统一图标样式吗？(Y = 保留 / N = 换成检测到的常用软件)"
    if ($keep -match '^[Yy]') { $nexusArgs = @{ KeepMyApps = $true } }
}

Invoke-Step '1/3 调整任务栏和桌面' 'apply-look.ps1'

if ($nexusExe) { Invoke-Step '2/3 导入 Nexus Dock' 'apply-nexus.ps1' $nexusArgs }
else { Skip-Step '2/3 导入 Nexus Dock' '没有安装 Nexus' }

if ($weExe) { Invoke-Step '3/3 Wallpaper Engine 开机自启' 'fix-wallpaper-autostart.ps1' }
else { Skip-Step '3/3 Wallpaper Engine 开机自启' '没有安装 Wallpaper Engine' }

Write-Host "`n== 结果 =="
$results | Format-Table -AutoSize

if ($results | Where-Object 结果 -eq '失败') {
    Write-Host '有步骤失败了，上面有具体原因。已完成的步骤可以用 restore.ps1 还原。'
    exit 1
}
Write-Host '完成！去 wallpapers.md 挑一张壁纸订阅吧。想还原，运行 restore.ps1。'
exit 0
