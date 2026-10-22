<#
  apply-look.ps1
  一键应用桌面外观：深色任务栏、透明效果、自动隐藏任务栏、隐藏桌面图标、
  隐藏"任务视图"按钮。

  用法：
    .\apply-look.ps1          应用设置（会先把当前设置备份到 backup\ 文件夹）
    .\apply-look.ps1 -Undo    恢复成运行脚本之前的设置
#>
param([switch]$Undo, [Parameter(DontShow = $true)][switch]$DesktopSession)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
# HKCU 外观设置必须与 Explorer 使用同一视图；整个事务（含备份和 Undo）在桌面执行。
if (-not $DesktopSession) {
    try {
        $code = Invoke-DesktopScript -ScriptPath $PSCommandPath -Parameters @{
            Undo = [bool]$Undo; DesktopSession = $true
        }
        exit $code
    } catch {
        Write-Host "外观桌面操作失败：$($_.Exception.Message)"
        exit 1
    }
}

$backupDir  = Join-Path $PSScriptRoot '..\backup'
$backupFile = Join-Path $backupDir 'look-backup.json'

$personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$advanced    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$stuckRects  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'

# 要修改的注册表项：路径、名称、目标值
$settings = @(
    @{ Path = $personalize; Name = 'SystemUsesLightTheme'; Value = 0 }  # 任务栏和开始菜单用深色
    @{ Path = $personalize; Name = 'EnableTransparency';   Value = 1 }  # 打开透明效果
    @{ Path = $advanced;    Name = 'HideIcons';            Value = 1 }  # 隐藏桌面图标
    @{ Path = $advanced;    Name = 'ShowTaskViewButton';   Value = 0 }  # 隐藏"任务视图"按钮
)

function Get-Value($path, $name) {
    $item = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
    if ($item) { return $item.$name } else { return $null }
}

function Restart-Explorer {
    # 在此名单追加进程名即可支持其他任务栏工具；只恢复重启前已运行的工具。
    $taskbarTools = @('TranslucentTB')
    $runningTools = @()
    $sessionId = (Get-Process -Id $PID).SessionId
    # 当前会话没有资源管理器（例如自动测试的虚拟机）时，设置已写入，下次启动生效，不算失败。
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId })) {
        Write-Host '当前会话没有运行资源管理器，跳过重启；设置会在下次启动资源管理器时生效。'
        return
    }
    foreach ($name in $taskbarTools) {
        try {
            $processes = @(Get-Process -Name $name -ErrorAction SilentlyContinue |
                Where-Object { $_.SessionId -eq $sessionId })
            if ($processes.Count -eq 0) { continue }

            $appId = $null
            try {
                $appId = Get-StartApps -ErrorAction Stop |
                    Where-Object { $_.AppID -match ([regex]::Escape($name)) -and $_.AppID -like '*!*' } |
                    Select-Object -First 1 -ExpandProperty AppID
            } catch {
                Write-Host "无法查询 $name 的 Store AppID，将尝试记录程序路径：$($_.Exception.Message)"
            }
            $path = $null
            if (-not $appId) {
                $path = $processes | Select-Object -First 1 -ExpandProperty Path
                if (-not $path) { throw '无法取得程序路径。' }
            }
            $runningTools += @{ Name = $name; AppID = $appId; Path = $path }
        } catch {
            Write-Host "无法记录任务栏工具 $name，请在重启后手动启动：$($_.Exception.Message)"
        }
    }

    Write-Host '正在重启资源管理器，任务栏会闪一下...'
    # 只重启当前会话的资源管理器，不碰其他用户会话。
    Get-Process -Name explorer -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionId -eq $sessionId } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sessionId })) {
        # 仅在系统未自动恢复桌面 shell 时引导启动；此时没有现存 Explorer 可转交。
        Start-Process -FilePath "$env:WINDIR\explorer.exe" -WindowStyle Hidden
        Start-Sleep -Seconds 2
    }

    foreach ($tool in $runningTools) {
        try {
            # 工具若自行恢复则不重复启动。
            if (Get-Process -Name $tool.Name -ErrorAction SilentlyContinue |
                Where-Object { $_.SessionId -eq $sessionId }) { continue }
            if ($tool.AppID) {
                Start-Detached -AppID $tool.AppID -ProcessName $tool.Name
            } else {
                Start-Detached -FilePath $tool.Path -ProcessName $tool.Name
            }
        } catch {
            throw "无法恢复任务栏工具 $($tool.Name)，请手动启动：$($_.Exception.Message)"
        }
    }
}

if ($Undo -and -not (Test-Path $backupFile)) { Write-Host '没有找到外观备份，无需还原。'; exit 0 }

if (-not (Test-Path $stuckRects)) {
    Write-Host '没有找到任务栏的设置项，这台电脑的 Windows 版本可能不支持，已停止，什么都没改。'
    exit 1
}

if ($Undo) {
    try {
        $backup = Get-Content $backupFile -Raw | ConvertFrom-Json
        foreach ($s in $backup.Items) {
            if (-not $s.KeyExisted) {
                # 这个注册表项是安装时新建的，里面没别的东西就整个删掉
                Remove-ItemProperty -Path $s.Path -Name $s.Name -ErrorAction SilentlyContinue
                $key = Get-Item $s.Path -ErrorAction SilentlyContinue
                if ($key -and $key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0) { Remove-Item $s.Path }
            } elseif ($null -eq $s.Value) {
                Remove-ItemProperty -Path $s.Path -Name $s.Name -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty -Path $s.Path -Name $s.Name -Value $s.Value -Type DWord
            }
        }
        $rects = (Get-ItemProperty $stuckRects).Settings
        $rects[8] = [byte]$backup.TaskbarAutoHide
        Set-ItemProperty -Path $stuckRects -Name Settings -Value $rects
        # 资源管理器启动时会按桌面视图的「不显示图标」位（FFlags 0x1000）改写 HideIcons，
        # 只还原 HideIcons 的话图标仍是隐藏的（自动往返测试发现），所以把这一位也设回原样。
        $desktopBag = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'
        $flags = Get-Value $desktopBag 'FFlags'
        if ($null -ne $flags) {
            $wasHidden = @($backup.Items | Where-Object { $_.Name -eq 'HideIcons' -and $_.Value -eq 1 }).Count -gt 0
            $flags = if ($wasHidden) { $flags -bor 0x1000 } else { $flags -band (-bnot 0x1000) }
            Set-ItemProperty -Path $desktopBag -Name FFlags -Value $flags -Type DWord
        }
        Restart-Explorer
        Remove-Item $backupFile
    } catch {
        Write-Host "恢复外观设置失败：$($_.Exception.Message)"
        exit 1
    }
    Write-Host '已恢复原来的外观设置。'
    exit 0
}

try {
    # 先备份当前值；已经有备份就不覆盖，保证多次运行后还能还原到最初的样子
    $rects = (Get-ItemProperty $stuckRects).Settings
    if (Test-Path $backupFile) {
        Write-Host "已有备份 $backupFile，保留不覆盖。"
    } else {
        New-Item -ItemType Directory -Force $backupDir | Out-Null
        $backup = @{
            Items = @($settings | ForEach-Object {
                @{ Path = $_.Path; Name = $_.Name; KeyExisted = (Test-Path $_.Path); Value = (Get-Value $_.Path $_.Name) }
            })
            TaskbarAutoHide = $rects[8]
        }
        $backup | ConvertTo-Json -Depth 4 | Set-Content $backupFile -Encoding UTF8
        Write-Host "当前设置已备份到 $backupFile"
    }

    foreach ($s in $settings) {
        if (-not (Test-Path $s.Path)) { New-Item -Path $s.Path -Force | Out-Null }
        Set-ItemProperty -Path $s.Path -Name $s.Name -Value $s.Value -Type DWord
    }

    # 自动隐藏任务栏：StuckRects3 的第 9 个字节，3 = 自动隐藏，2 = 常驻；其余字节原样保留
    $rects[8] = 3
    Set-ItemProperty -Path $stuckRects -Name Settings -Value $rects

    Restart-Explorer
} catch {
    Write-Host "应用外观设置失败：$($_.Exception.Message)"
    Write-Host '可以运行 .\apply-look.ps1 -Undo 恢复。'
    exit 1
}
Write-Host '外观设置完成。想恢复原样，运行：.\apply-look.ps1 -Undo'
exit 0
