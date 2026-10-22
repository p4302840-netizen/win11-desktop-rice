<#
  切换创意工坊壁纸，首次切换前保存原始配置；-Undo 由 restore.ps1 调用。
  -NoWait：未下载时打开订阅页后立即返回 2；默认每 5 秒检查，最多等 3 分钟。
  退出码：0 命令执行成功（画面须人工验证）；2 需要用户处理；1 操作失败。
#>
[CmdletBinding(DefaultParameterSetName = 'Apply')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [ValidateSet('landscape', 'ink', 'cyber')][string]$Style,
    [Parameter(ParameterSetName = 'Apply')][switch]$NoWait,
    [Parameter(Mandatory = $true, ParameterSetName = 'Undo')][switch]$Undo
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"
$styles = @{ landscape = '3683255353'; ink = '3073167683'; cyber = '2447094306' }
$backupDir = Join-Path $PSScriptRoot '..\backup'
$stateFile = Join-Path $backupDir 'wallpaper-style-backup.json'
$snapshot = Join-Path $backupDir 'wallpaper-config-backup.json'

# 只关闭当前会话、本安装目录内的引擎和界面，不碰服务或其他用户的进程。
function Stop-LocalWallpaperEngine([string]$directory) {
    $prefix = $directory.TrimEnd('\') + '\'
    $session = (Get-Process -Id $PID).SessionId
    $processes = @(Get-Process -Name wallpaper32, wallpaper64, ui32 -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionId -eq $session -and $_.Path -and $_.Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
    foreach ($process in $processes) {
        # 先保留句柄，避免进程退出后再获取句柄导致 WaitForExit 失败。
        $null = $process.Handle
        Stop-Process -Id $process.Id -Force
        if (-not $process.WaitForExit(10000)) { throw 'Wallpaper Engine 未能退出，已停止写入配置。' }
    }
}

# 不依赖某个版本的配置层级；原始配置完整备份，路径清单只用于人工审查。
function Get-WallpaperPaths($node) {
    if ($node -is [string]) {
        if ($node -match '(?i)\.(json|pkg|mp4|webm|avi|wmv|html|htm|gif|jpg|jpeg|png)$') { $node }
    } elseif ($node -is [pscustomobject]) {
        foreach ($property in $node.PSObject.Properties) { Get-WallpaperPaths $property.Value }
    } elseif ($node -is [System.Collections.IEnumerable]) {
        foreach ($item in $node) { Get-WallpaperPaths $item }
    }
}

function Find-StyleProject([string]$id) {
    foreach ($library in Get-SteamLibraries) {
        $project = Join-Path $library "steamapps\workshop\content\431960\$id\project.json"
        # 文件夹出现不代表下载完成，至少要求 project.json 可解析。
        if (Test-Path -LiteralPath $project -PathType Leaf) {
            try {
                $null = Get-Content -LiteralPath $project -Raw -Encoding UTF8 | ConvertFrom-Json
                return $project
            } catch { Write-Verbose "壁纸描述文件尚未完整：$project" }
        }
    }
    return $null
}

try {
    if ($Undo -and -not (Test-Path -LiteralPath $stateFile)) {
        Write-Host '没有找到壁纸切换记录，无需还原。'
        exit 0
    }
    $exe = Find-WallpaperEngine
    if (-not $exe) { Write-Host '请先通过 Steam 安装 Wallpaper Engine：steam://install/431960'; exit 2 }
    $directory = Split-Path $exe
    $configFile = Join-Path $directory 'config.json'

    if ($Undo) {
        $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($state.Version -ne 1 -or $state.ConfigPath -ne $configFile -or
            -not (Test-Path -LiteralPath $snapshot) -or
            (Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -ne $state.ConfigHash) {
            throw '壁纸备份不完整、校验失败或安装目录已改变，请保留 backup 手动核查。'
        }
        $null = Get-Content -LiteralPath $snapshot -Raw -Encoding UTF8 | ConvertFrom-Json
        Stop-LocalWallpaperEngine $directory
        # 还原前另存当前配置；失败时保留所有备份，方便重试。
        if (Test-Path -LiteralPath $configFile) {
            Copy-Item -LiteralPath $configFile -Destination (Join-Path $backupDir 'wallpaper-config-before-undo.json') -Force
        }
        Copy-Item -LiteralPath $snapshot -Destination $configFile -Force
        Start-Detached -FilePath $exe -ProcessName wallpaper32, wallpaper64
        # 先移除状态，再清理快照，避免清理中断后留下指向缺失快照的有效记录。
        Remove-Item -LiteralPath $stateFile
        Remove-Item -LiteralPath $snapshot
        $beforeUndo = Join-Path $backupDir 'wallpaper-config-before-undo.json'
        if (Test-Path -LiteralPath $beforeUndo) { Remove-Item -LiteralPath $beforeUndo }
        Write-Host '已恢复切换前的完整配置并重新启动；请核对原壁纸和各显示器。'
        exit 0
    }

    $id = $styles[$Style]
    $project = Find-StyleProject $id
    if (-not $project) {
        $url = "steam://url/CommunityFilePage/$id"
        Write-Host "请用户在 Steam 页面亲自点「订阅」，等待下载完成：$url"
        & "$env:WINDIR\explorer.exe" $url
        if (-not $NoWait) {
            $deadline = (Get-Date).AddMinutes(3)
            while (-not $project -and (Get-Date) -lt $deadline) {
                Start-Sleep -Seconds 5
                $project = Find-StyleProject $id
            }
        }
        if (-not $project) { Write-Host '壁纸尚未下载完成或等待超时，请检查 Steam 下载后重试。'; exit 2 }
    }

    Write-Host '未确认高优先级对应的 config.json 字段，不自动修改。请用户在 Wallpaper Engine 设置里关闭「高优先级」。'
    if (-not (Test-Path -LiteralPath $configFile)) {
        Write-Host '找不到 config.json；请先打开 Wallpaper Engine 选择壁纸并退出一次，以便安全备份。'
        exit 2
    }
    # 停止写入者后再复制，保留磁盘上最后保存的壁纸配置。
    Stop-LocalWallpaperEngine $directory
    $config = Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    if (Test-Path -LiteralPath $stateFile) {
        $state = Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($state.Version -ne 1 -or $state.ConfigPath -ne $configFile -or
            -not (Test-Path -LiteralPath $snapshot) -or
            (Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -ne $state.ConfigHash) {
            throw '已有壁纸备份无法通过校验，停止切换，保留备份供核查。'
        }
        Write-Host '已有首次切换备份，保留不覆盖。'
    } else {
        Copy-Item -LiteralPath $configFile -Destination $snapshot -Force
        [ordered]@{
            Version = 1
            ConfigPath = $configFile
            ConfigHash = (Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash
            PreviousWallpaperPaths = @(Get-WallpaperPaths $config | Sort-Object -Unique)
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stateFile -Encoding UTF8
    }
    # 先启动引擎，避免控制命令成为常驻进程；控制命令有独立的超时检查。
    Start-Detached -FilePath $exe -ProcessName wallpaper32, wallpaper64
    Start-Sleep -Seconds 3
    $control = Start-Process -FilePath $exe -WorkingDirectory $directory -ArgumentList @(
        '-control', 'openWallpaper', '-file', ('"' + $project + '"')
    ) -PassThru
    $null = $control.Handle
    if (-not $control.WaitForExit(15000)) { throw '壁纸控制命令 15 秒未返回，请检查 Wallpaper Engine 状态。' }
    if ($control.ExitCode -ne 0) { throw "壁纸控制命令失败：$($control.ExitCode)" }
    Write-Host "风格 $Style 的切换命令已执行：$project"
    Write-Host '退出码 0 只表示命令正常返回，请检查实际画面；可用 restore.ps1 还原。'
    exit 0
} catch {
    Write-Host "壁纸操作失败：$($_.Exception.Message)"
    Write-Host '已有备份会保留；若引擎已退出，请手动重新打开，修复问题后运行 restore.ps1。'
    exit 1
}
