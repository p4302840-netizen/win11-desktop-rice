<#
  restore.ps1
  把 install.ps1 做的改动还原成安装之前的样子。
  某一步失败不会影响其他步骤，失败的那一步备份会保留，可以修好后再运行一次。

  用法（在本文件夹里打开终端）：
    powershell -ExecutionPolicy Bypass -File .\restore.ps1
#>

$scripts = Join-Path $PSScriptRoot 'scripts'
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Step([string]$name, [string]$script) {
    Write-Host "`n== $name =="
    $global:LASTEXITCODE = 0
    try {
        & "$scripts\$script" -Undo
        $ok = ($LASTEXITCODE -eq 0)
    } catch {
        Write-Host "出错：$($_.Exception.Message)"
        $ok = $false
    }
    $results.Add([pscustomobject]@{ 步骤 = $name; 结果 = $(if ($ok) { '完成' } else { '失败' }) })
}

# 每个子脚本自己判断有没有备份：没有就什么都不做
Invoke-Step '还原壁纸和 Wallpaper Engine 配置' 'set-style.ps1'
Invoke-Step '还原任务栏和桌面' 'apply-look.ps1'
Invoke-Step '还原 Nexus Dock' 'apply-nexus.ps1'
Invoke-Step '还原 Wallpaper Engine 自启' 'fix-wallpaper-autostart.ps1'

Write-Host "`n== 结果 =="
$results | Format-Table -AutoSize

if ($results | Where-Object 结果 -eq '失败') {
    Write-Host "有步骤没还原成功，对应的备份还留在 $PSScriptRoot\backup，可以再运行一次 restore.ps1。"
    exit 1
}
Write-Host '还原完成。'
exit 0
