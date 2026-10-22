<#
  common.ps1
  各脚本共用的检测函数。不要直接运行，由其他脚本用 . "$PSScriptRoot\common.ps1" 引入。
#>

# 所有 Steam 库文件夹（主目录 + libraryfolders.vdf 里登记的其他盘）
function Get-SteamLibraries {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return @() }
    $libs = @($steam -replace '/', '\')
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $libs += Select-String -Path $vdf -Pattern '"path"\s+"(.+)"' |
            ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' }
    }
    return @($libs | Where-Object { Test-Path $_ } | Sort-Object -Unique)
}

# Wallpaper Engine 主程序路径，没装返回 $null
function Find-WallpaperEngine {
    foreach ($lib in Get-SteamLibraries) {
        $exe = Join-Path $lib 'steamapps\common\wallpaper_engine\wallpaper32.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}

# Nexus 主程序路径：先看正在运行的进程，再查卸载信息，最后试默认位置
function Find-Nexus {
    $running = Get-Process -Name Nexus -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($running -and $running.Path) { return $running.Path }

    $uninstallKeys = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
                     'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
                     'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    $entry = Get-ChildItem $uninstallKeys -ErrorAction SilentlyContinue | Get-ItemProperty |
        Where-Object { $_.DisplayName -eq 'Nexus' -and $_.InstallLocation } | Select-Object -First 1
    if ($entry) {
        $exe = Join-Path $entry.InstallLocation 'Nexus.exe'
        if (Test-Path $exe) { return $exe }
    }

    foreach ($dir in "${env:ProgramFiles(x86)}\Winstep", "$env:ProgramFiles\Winstep") {
        $exe = Join-Path $dir 'Nexus.exe'
        if (Test-Path $exe) { return $exe }
    }
    return $null
}
