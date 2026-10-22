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
