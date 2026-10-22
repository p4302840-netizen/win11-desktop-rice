<#
  scan-disk.ps1
  扫描常见的"占空间大户"，只列出大小，不删除任何东西。
  看完结果后，自己决定要清理哪个。

  用法：
    .\scan-disk.ps1
#>

. "$PSScriptRoot\common.ps1"

$targets = [ordered]@{
    '系统临时文件' = $env:TEMP
    '下载文件夹'   = Join-Path $env:USERPROFILE 'Downloads'
    'npm 缓存'     = Join-Path $env:LOCALAPPDATA 'npm-cache'
    'pip 缓存'     = Join-Path $env:LOCALAPPDATA 'pip\Cache'
    '微信文件'     = Join-Path $env:USERPROFILE 'Documents\WeChat Files'
    'QQ 文件'      = Join-Path $env:USERPROFILE 'Documents\Tencent Files'
}

# 每个 Steam 库单独列一行。Wallpaper Engine 壁纸包含在创意工坊里，单独列出方便对比
foreach ($lib in Get-SteamLibraries) {
    $ws = Join-Path $lib 'steamapps\workshop'
    if (Test-Path $ws) { $targets["Steam 创意工坊（$lib）"] = $ws }
    $we = Join-Path $lib 'steamapps\workshop\content\431960'
    if (Test-Path $we) { $targets["  其中 Wallpaper Engine 壁纸（$lib）"] = $we }
}

function Get-FolderSize($path) {
    (Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
}

Write-Host '正在扫描，文件多的话要等一会儿...'
$rows = foreach ($name in $targets.Keys) {
    $path = $targets[$name]
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { continue }
    [pscustomobject]@{
        项目   = $name
        大小GB = [math]::Round((Get-FolderSize $path) / 1GB, 2)
        位置   = $path
    }
}
$rows | Format-Table -AutoSize

Write-Host '各磁盘剩余空间：'
Get-PSDrive -PSProvider FileSystem | Where-Object Used |
    Select-Object @{ n = '盘符'; e = { $_.Name } },
                  @{ n = '已用GB'; e = { [math]::Round($_.Used / 1GB, 1) } },
                  @{ n = '剩余GB'; e = { [math]::Round($_.Free / 1GB, 1) } } |
    Format-Table -AutoSize

Write-Host '提示：这个脚本不会删除任何文件。清理前请确认里面没有你要的东西。'
