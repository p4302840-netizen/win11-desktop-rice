<#
  fix-wallpaper-autostart.ps1
  修复"开机后 Wallpaper Engine 壁纸不出来"的问题。

  原因：Wallpaper Engine 设置里勾选了"高优先级"后，它改成靠一个后台服务开机启动。
  如果这个服务被优化软件改成了"手动"，或原来的启动项被关掉，开机时就没人去启动它。

  做法：自动找到 Wallpaper Engine 的安装位置，建一个"登录后延迟 10 秒启动"的计划任务。
  不需要管理员权限。如果你原来已有同名任务，会先把它完整备份下来。

  用法：
    .\fix-wallpaper-autostart.ps1          创建或更新计划任务
    .\fix-wallpaper-autostart.ps1 -Undo    还原：有备份就恢复原任务，是本脚本新建的就删除
#>
param([Alias('Remove')][switch]$Undo)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

$taskName   = 'WallpaperEngine_Logon'
$backupDir  = Join-Path $PSScriptRoot '..\backup'
$backupXml  = Join-Path $backupDir 'wallpaper-task-backup.xml'    # 原有任务的完整备份
$marker     = Join-Path $backupDir 'wallpaper-task-created.txt'   # 任务是本脚本新建的

if ($Undo) {
    try {
        if (Test-Path $backupXml) {
            $xml = Get-Content $backupXml -Raw -Encoding Unicode
            Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null
            Remove-Item $backupXml
            Write-Host "已把计划任务 $taskName 恢复成你原来的设置。"
        } elseif (Test-Path $marker) {
            if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }
            Remove-Item $marker
            Write-Host "已删除本工具新建的计划任务 $taskName。"
        } else {
            Write-Host '没有本工具留下的记录，计划任务保持不动。'
        }
        exit 0
    } catch {
        Write-Host "还原计划任务失败：$($_.Exception.Message)"
        exit 1
    }
}

$exe = Find-WallpaperEngine
if (-not $exe) {
    Write-Host '没有找到 Wallpaper Engine，请确认已经通过 Steam 安装。'
    exit 1
}
Write-Host "找到 Wallpaper Engine：$exe"

try {
    New-Item -ItemType Directory -Force $backupDir | Out-Null
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    $createdByUs = $false
    if ($existing) {
        # 已有备份或标记说明之前运行过，不要把改过的任务当成原始状态再备份一次
        if (-not (Test-Path $backupXml) -and -not (Test-Path $marker)) {
            Export-ScheduledTask -TaskName $taskName | Set-Content $backupXml -Encoding Unicode
            Write-Host "你原来就有计划任务 $taskName，已完整备份到 $backupXml"
        }
    } else {
        $createdByUs = $true
    }

    $action    = New-ScheduledTaskAction -Execute $exe
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $trigger.Delay = 'PT10S'   # 等桌面加载完再启动，避免壁纸闪一下就没了
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force | Out-Null

    # 注册成功后才写标记
    if ($createdByUs -and -not (Test-Path $backupXml)) {
        Set-Content $marker 'created by fix-wallpaper-autostart.ps1'
    }
} catch {
    Write-Host "创建计划任务失败：$($_.Exception.Message)"
    exit 1
}

Write-Host "已设置计划任务 $taskName，下次登录 10 秒后会自动启动壁纸。"
Write-Host '提醒：以后在 Wallpaper Engine 设置里不要勾选"高优先级"，否则会换回依赖后台服务的启动方式。'
exit 0
