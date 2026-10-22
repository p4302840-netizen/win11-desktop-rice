<#
  common.ps1
  各脚本共用的检测函数。不要直接运行，由其他脚本用 . "$PSScriptRoot\common.ps1" 引入。

  仅供自动测试：环境变量 RICE_DIRECT=1 时，Start-Detached 和 Invoke-DesktopScript
  不经 explorer.exe 转交，直接在当前进程/会话执行。GitHub Actions 虚拟机上没有可靠的
  用户桌面 Explorer，只能这样跑往返测试。用户电脑上不要设置它：直接执行就失去了
  绕开注册表隔离和进程回收的保护。
#>

# 是否处于测试用的直接执行模式（见文件开头说明）。
function Test-DirectMode { return $env:RICE_DIRECT -eq '1' }

# 经资源管理器启动常驻程序，避免受控终端退出时连同子进程一起结束。
function Start-Detached {
    [CmdletBinding(DefaultParameterSetName = 'Executable')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Executable')][string]$FilePath,
        [Parameter(Mandatory = $true, ParameterSetName = 'Store')][string]$AppID,
        [string[]]$ProcessName,
        [int]$TimeoutSeconds = 15
    )
    $directory = $null
    if ($AppID) {
        if (-not $ProcessName) { throw '启动 Store 应用时必须指定进程名。' }
        $target = "shell:AppsFolder\$AppID"
    } else {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "找不到程序：$FilePath" }
        $target = (Get-Item -LiteralPath $FilePath).FullName
        $directory = Split-Path $target
        if (-not $ProcessName) { $ProcessName = @([IO.Path]::GetFileNameWithoutExtension($target)) }
    }
    $session = (Get-Process -Id $PID).SessionId
    if (Test-DirectMode) {
        # 测试模式：直接启动，仍按下面的进程检查确认启动成功。
        if ($directory) { Start-Process -FilePath $target -WorkingDirectory $directory }
        else { Start-Process -FilePath $target }
    } else {
        & "$env:WINDIR\explorer.exe" ('"' + $target + '"')
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $running = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object {
            $_.SessionId -eq $session -and
            (-not $directory -or ($_.Path -and (Split-Path $_.Path) -eq $directory))
        })
        if ($running.Count -gt 0) {
            Write-Host "已通过 Explorer 启动 $target，PID：$(($running | ForEach-Object Id) -join '、')"
            return
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "通过 Explorer 启动后，$TimeoutSeconds 秒内未检测到程序：$target"
}

# 受控环境和 Explorer 可能使用不同的 HKCU 视图。配置 Nexus 时交给普通桌面
# PowerShell 执行整个事务（包括备份），不能只把程序启动移到 Explorer。
function Invoke-DesktopScript {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [int]$TimeoutSeconds = 120
    )
    if (Test-DirectMode) {
        # 测试模式：在当前进程执行同一脚本，退出码含义与工作进程一致。
        $global:LASTEXITCODE = 0
        try {
            & $ScriptPath @Parameters | Out-Host
            return [int]$LASTEXITCODE
        } catch {
            Write-Host ($_ | Out-String)
            return 1
        }
    }
    $work = Join-Path ([IO.Path]::GetTempPath()) ('desktop-rice-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -ErrorAction Stop | Out-Null
    $completed = $false
    try {
        @{ ScriptPath = (Get-Item -LiteralPath $ScriptPath -ErrorAction Stop).FullName; Parameters = $Parameters } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $work 'request.json') -Encoding UTF8
        $worker = @'
$ErrorActionPreference = 'Stop'
$code = 1
try {
    $request = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'request.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $parameters = @{}
    foreach ($property in $request.Parameters.PSObject.Properties) { $parameters[$property.Name] = $property.Value }
    $global:LASTEXITCODE = 0
    & $request.ScriptPath @parameters *> (Join-Path $PSScriptRoot 'output.log')
    $code = $LASTEXITCODE
} catch {
    $_ | Out-String | Add-Content -LiteralPath (Join-Path $PSScriptRoot 'output.log') -Encoding UTF8
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'exit-code.tmp'), [string]$code)
Move-Item -LiteralPath (Join-Path $PSScriptRoot 'exit-code.tmp') -Destination (Join-Path $PSScriptRoot 'exit-code.txt')
'@
        $workerPath = Join-Path $work 'worker.ps1'
        [IO.File]::WriteAllText($workerPath, $worker, [Text.UTF8Encoding]::new($true))
        $shell = New-Object -ComObject WScript.Shell
        $linkPath = Join-Path $work 'worker.lnk'
        $link = $shell.CreateShortcut($linkPath)
        $link.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        $link.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $workerPath + '"'
        $link.WorkingDirectory = Split-Path $ScriptPath
        $link.Save()
        & "$env:WINDIR\explorer.exe" ('"' + $linkPath + '"')
        $result = Join-Path $work 'exit-code.txt'
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        while (-not (Test-Path -LiteralPath $result)) {
            if ((Get-Date) -ge $deadline) { throw "桌面工作进程未返回，可能仍在执行；请勿重复运行。检查：$work" }
            Start-Sleep -Milliseconds 500
        }
        $completed = $true
        $log = Join-Path $work 'output.log'
        if (Test-Path -LiteralPath $log) { Write-Host (Get-Content -LiteralPath $log -Raw) }
        return [int](Get-Content -LiteralPath $result -Raw)
    } finally {
        if ($completed) { Remove-Item -LiteralPath $work -Recurse -Force }
    }
}

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

# 读取文件的 256x256 系统大图标（和资源管理器"超大图标"看到的一样）
if (-not ('JumboIcon' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public static class JumboIcon {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  struct SHFILEINFO { public IntPtr hIcon; public int iIcon; public uint attr;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string name;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)] public string type; }
  [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
  static extern IntPtr SHGetFileInfo(string path, uint attr, ref SHFILEINFO info, uint size, uint flags);
  [ComImport, Guid("46EB5926-582E-4017-9FDF-E8998DAA0950"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IImageList {
    int Add(IntPtr a, IntPtr b, ref int c); int ReplaceIcon(int a, IntPtr b, ref int c); int SetOverlayImage(int a, int b);
    int Replace(int a, IntPtr b, IntPtr c); int AddMasked(IntPtr a, int b, ref int c); int Draw(IntPtr a); int Remove(int a);
    int GetIcon(int i, int flags, ref IntPtr icon); }
  [DllImport("shell32.dll", EntryPoint = "#727")]
  static extern int SHGetImageList(int list, ref Guid riid, out IImageList ppv);
  [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr h);
  public static Bitmap Get(string path) {
    var info = new SHFILEINFO();
    SHGetFileInfo(path, 0, ref info, (uint)Marshal.SizeOf(info), 0x4000);   // SHGFI_SYSICONINDEX
    var iid = new Guid("46EB5926-582E-4017-9FDF-E8998DAA0950");
    IImageList list; SHGetImageList(4, ref iid, out list);                  // SHIL_JUMBO
    IntPtr h = IntPtr.Zero; list.GetIcon(info.iIcon, 1, ref h);             // ILD_TRANSPARENT
    var bmp = Icon.FromHandle(h).ToBitmap(); DestroyIcon(h); return bmp;
  }
}
'@
}

# 把软件的原图标统一成同样的视觉大小，存成 256x256 透明 PNG。
# 圆形图标比方形图标看起来小，所以画得稍大一点，整排看起来才一样大。
# $Source 可以是 exe/lnk（取系统大图标），也可以是现成的 png/ico 图片。
function Export-AppIcon([string]$Source, [string]$OutFile) {
    Add-Type -AssemblyName System.Drawing
    if ($Source -match '\.(png|ico)$') { $src = New-Object System.Drawing.Bitmap $Source }
    else { $src = [JumboIcon]::Get($Source) }
    try {
        # 找出不透明部分的边界，去掉图标自带的留白
        $minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
        for ($y = 0; $y -lt $src.Height; $y += 2) {
            for ($x = 0; $x -lt $src.Width; $x += 2) {
                if ($src.GetPixel($x, $y).A -gt 24) {
                    if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }
        if ($maxX -lt 0) { throw "图标是空的：$Source" }
        $w = $maxX - $minX + 2; $h = $maxY - $minY + 2

        # 判断形状：离左上角 10% 的位置，圆形是透明的，圆角方形是实心的
        $probe = $src.GetPixel([int]($minX + $w * 0.10), [int]($minY + $h * 0.10)).A
        $target = if ($probe -lt 40) { 232 } else { 216 }

        $scale = $target / [Math]::Max($w, $h)
        $dw = [int]($w * $scale); $dh = [int]($h * $scale)
        $out = New-Object System.Drawing.Bitmap 256, 256
        $g = [System.Drawing.Graphics]::FromImage($out)
        $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.SmoothingMode = 'HighQuality'
        $dest = New-Object System.Drawing.Rectangle ([int]((256 - $dw) / 2)), ([int]((256 - $dh) / 2)), $dw, $dh
        $g.DrawImage($src, $dest, $minX, $minY, $w, $h, [System.Drawing.GraphicsUnit]::Pixel)
        $g.Dispose()
        $out.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
        $out.Dispose()
    } finally {
        $src.Dispose()
    }
}
