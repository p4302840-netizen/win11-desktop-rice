<#
  apply-nexus.ps1
  把 config\nexus-dock.json 里的 Dock 外观导入你的 Nexus，
  并把 Dock 上每个软件的原图标统一成同样的视觉大小。

  两种模式：
    默认          检测你电脑上是否装了几款常用软件（只查常见安装位置），用它们替换第一个 Dock 的图标列表
    -KeepMyApps   保留你 Dock 上现有的软件，只统一图标大小和外观

  原配置会先备份，可以还原。图标从你电脑上的软件里提取，存在 %APPDATA%\NexusDock\win11-desktop-rice-icons。

  用法：
    .\apply-nexus.ps1                导入并替换图标列表
    .\apply-nexus.ps1 -KeepMyApps    导入并保留你自己的软件
    .\apply-nexus.ps1 -Undo          恢复成导入之前的样子
#>
param([switch]$Undo, [switch]$KeepMyApps)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\common.ps1"

$regKey     = 'HKCU\Software\WinSTEP2000\NeXuS'      # 只备份和还原 Nexus 自己的这一块
$nexusKey   = 'HKCU:\Software\WinSTEP2000\NeXuS'
$docksKey   = "$nexusKey\Docks"
$configFile = Join-Path $PSScriptRoot '..\config\nexus-dock.json'
$backupDir  = Join-Path $PSScriptRoot '..\backup'
$backupFile = Join-Path $backupDir 'nexus-backup.reg'
$iconDir    = Join-Path $env:APPDATA 'NexusDock\win11-desktop-rice-icons'
$nexusExe   = Find-Nexus

# 生成统一大小的图标，返回 PNG 路径；提取失败就沿用原来的图标，不影响导入
function Get-UnifiedIcon([string]$source) {
    if (-not $source -or -not (Test-Path $source)) { return $source }
    # 已经是统一过的图标（重复运行时），直接沿用
    if ($source.StartsWith($iconDir, [StringComparison]::OrdinalIgnoreCase)) { return $source }
    try {
        New-Item -ItemType Directory -Force $iconDir | Out-Null
        $md5 = [Security.Cryptography.MD5]::Create()
        $hash = -join ($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($source.ToLower())) | Select-Object -First 6 | ForEach-Object { $_.ToString('x2') })
        $png = Join-Path $iconDir "$hash.png"
        Export-AppIcon $source $png
        return $png
    } catch {
        Write-Host "  图标处理失败，沿用原图标：$source"
        return $source
    }
}

function Stop-Nexus {
    # 直接结束进程，避免 Nexus 退出时把旧设置写回注册表
    Get-Process -Name Nexus -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
}

function Start-Nexus {
    if ($nexusExe) { Start-Process $nexusExe; Write-Host 'Nexus 已重新启动。' }
}

# reg.exe 会把"操作成功"写到错误输出，PowerShell 5.1 会误判成出错，所以交给 cmd 执行
function Invoke-Reg([string]$arguments) {
    cmd /c "reg $arguments >nul 2>&1"
    return ($LASTEXITCODE -eq 0)
}

if ($Undo) {
    if (-not (Test-Path $backupFile)) { Write-Host '没有找到 Nexus 备份，无需还原。'; exit 0 }
    if (-not (Select-String -Path $backupFile -SimpleMatch "[$($regKey -replace '^HKCU', 'HKEY_CURRENT_USER')]" -Quiet)) {
        Write-Host "备份文件不完整，已停止，什么都没改：$backupFile"
        exit 1
    }

    Stop-Nexus
    # 先把当前状态另存一份，万一导入失败还能退回来
    $current = Join-Path $backupDir 'nexus-before-undo.reg'
    $hadKey = Test-Path $nexusKey
    if ($hadKey -and -not (Invoke-Reg "export `"$regKey`" `"$current`" /y")) {
        Write-Host '无法保存当前配置，已停止，什么都没改。'
        Start-Nexus
        exit 1
    }
    if ($hadKey) { Invoke-Reg "delete `"$regKey`" /f" | Out-Null }

    if (-not (Invoke-Reg "import `"$backupFile`"")) {
        if ($hadKey) { Invoke-Reg "import `"$current`"" | Out-Null }
        Write-Host "恢复失败，已退回到还原前的状态。备份文件还在：$backupFile"
        Start-Nexus
        exit 1
    }

    # 恢复出来的配置如果没用到导入时生成的图标，就把图标文件夹删掉
    $stillUsed = Select-String -Path $backupFile -SimpleMatch 'win11-desktop-rice-icons' -Quiet
    Remove-Item $backupFile
    if ($hadKey) { Remove-Item $current }
    if (-not $stillUsed) { Remove-Item $iconDir -Recurse -Force -ErrorAction SilentlyContinue }
    Start-Nexus
    Write-Host '已恢复原来的 Nexus 配置。'
    exit 0
}

if (-not $nexusExe) {
    Write-Host '没有找到 Nexus，请先从 https://www.winstep.net/nexus.htm 下载安装。'
    exit 1
}
if (-not (Test-Path $docksKey)) {
    Write-Host '还没有 Nexus 的配置。请先运行一次 Nexus，等 Dock 出现后再运行这个脚本。'
    exit 1
}

# 先备份；已经有备份就不覆盖，保证多次运行后还能还原到最初的样子
New-Item -ItemType Directory -Force $backupDir | Out-Null
if (Test-Path $backupFile) {
    Write-Host "已有备份 $backupFile，保留不覆盖。"
} elseif (Invoke-Reg "export `"$regKey`" `"$backupFile`" /y") {
    Write-Host "原来的 Nexus 配置已备份到 $backupFile"
} else {
    Write-Host '备份 Nexus 配置失败，已停止，什么都没改。'
    exit 1
}

# 要放到 Dock 上的软件：按顺序检测常见安装位置，装了的才加
function Find-First($pattern) {
    Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
$steamExe = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
$candidates = @(
    @{ Label = '文件资源管理器'; Path = "$env:WINDIR\explorer.exe" }
    @{ Label = 'Edge';           Path = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe" }
    @{ Label = 'Chrome';         Path = (Find-First "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") }
    @{ Label = 'QQ';             Path = "$env:ProgramFiles\Tencent\QQNT\QQ.exe" }
    @{ Label = '微信';           Path = (Find-First "$env:ProgramFiles\Tencent\Weixin\Weixin.exe", "${env:ProgramFiles(x86)}\Tencent\WeChat\WeChat.exe") }
    @{ Label = 'Steam';          Path = $(if ($steamExe) { $steamExe -replace '/', '\' }) }
    @{ Label = 'QQ音乐';         Path = (Find-First "${env:ProgramFiles(x86)}\Tencent\QQMusic\*\QQMusic.exe") }
    @{ Label = '网易云音乐';     Path = (Find-First "$env:ProgramFiles\NetEase\CloudMusic\cloudmusic.exe", "${env:ProgramFiles(x86)}\NetEase\CloudMusic\cloudmusic.exe") }
)
$apps = @($candidates | Where-Object { $_.Path -and (Test-Path $_.Path) })

$config = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json

# 配置里的主题路径以作者电脑的公共文档目录开头，换成这台电脑的
$authorPublicDocs = 'C:\Users\Public\Documents'
$localPublicDocs  = [Environment]::GetFolderPath('CommonDocuments')
function Convert-ThemePath([string]$value) {
    if ($value.StartsWith($authorPublicDocs, [StringComparison]::OrdinalIgnoreCase)) {
        return $localPublicDocs + $value.Substring($authorPublicDocs.Length)
    }
    return $value
}

$themeFolder = Convert-ThemePath $config.theme.NeXuSBitmapFolder
$themeFound  = Test-Path $themeFolder
if (-not $themeFound) {
    Write-Host "没找到 Dock 主题文件夹 $themeFolder，跳过主题，只导入图标大小、放大效果等设置。"
}

try {
    Stop-Nexus

    if ($themeFound) {
        foreach ($p in $config.theme.PSObject.Properties) {
            Set-ItemProperty -Path $nexusKey -Name $p.Name -Value (Convert-ThemePath ([string]$p.Value)) -Type String
        }
    }
    foreach ($p in $config.dock.PSObject.Properties) {
        $value = Convert-ThemePath ([string]$p.Value)
        # 主题缺失时，不写指向主题文件的设置，免得 Dock 背景变空白
        if (-not $themeFound -and $value -match '^[A-Za-z]:\\') { continue }
        Set-ItemProperty -Path $docksKey -Name $p.Name -Value $value -Type String
    }

    $docks = Get-Item $docksKey
    if ($KeepMyApps) {
        # 保留现有软件，只把每个图标换成统一大小的版本
        $last = [int]$docks.GetValue('DockNoItems1', -1)
        $labels = @()
        for ($i = 0; $i -le $last; $i++) {
            $icon = $docks.GetValue("1IconPath$i")
            if (-not $icon) { $icon = $docks.GetValue("1Path$i") }
            if (-not $icon) { continue }
            Set-ItemProperty -Path $docksKey -Name "1IconPath$i" -Value (Get-UnifiedIcon $icon) -Type String
            $labels += $docks.GetValue("1Label$i")
        }
        $summary = "保留了你的 $($labels.Count) 个软件，统一了图标：$($labels -join '、')"
    } else {
        # 先清掉第 1 个 Dock 原有的图标，再按检测结果写入
        foreach ($name in $docks.GetValueNames()) {
            if ($name -match '^1[A-Za-z]+\d+$') { Remove-ItemProperty -Path $docksKey -Name $name }
        }
        for ($i = 0; $i -lt $apps.Count; $i++) {
            $a = $apps[$i]
            Set-ItemProperty -Path $docksKey -Name "1Path$i"      -Value $a.Path -Type String
            Set-ItemProperty -Path $docksKey -Name "1Label$i"     -Value $a.Label -Type String
            Set-ItemProperty -Path $docksKey -Name "1IconPath$i"  -Value (Get-UnifiedIcon $a.Path) -Type String
            Set-ItemProperty -Path $docksKey -Name "1StartPath$i" -Value ((Split-Path $a.Path) + '\') -Type String
            Set-ItemProperty -Path $docksKey -Name "1Type$i"      -Value '1' -Type String
        }
        # Nexus 记的是最后一个图标的序号，不是图标个数
        Set-ItemProperty -Path $docksKey -Name 'DockNoItems1' -Value ([string]($apps.Count - 1)) -Type String
        $summary = "放上了 $($apps.Count) 个软件：$(($apps | ForEach-Object Label) -join '、')"
    }
} catch {
    Write-Host "导入失败：$($_.Exception.Message)"
    Write-Host '可以运行 .\apply-nexus.ps1 -Undo 恢复原来的配置。'
    Start-Nexus
    exit 1
}

Start-Nexus
Write-Host "Dock 外观已导入，$summary"
Write-Host '其他软件可以直接拖到 Dock 上。想恢复原样，运行：.\apply-nexus.ps1 -Undo'
exit 0
