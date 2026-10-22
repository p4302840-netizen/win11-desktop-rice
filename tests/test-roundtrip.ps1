<#
  test-roundtrip.ps1
  「安装 → 重复安装 → 还原」往返测试，以及备份损坏时的失败路径。

  会改当前用户的桌面注册表、计划任务和 Program Files，只允许在 GitHub Actions 的
  一次性 Windows 虚拟机上运行（.github/workflows/roundtrip.yml）。不要在自己电脑上运行。

  不安装付费软件，而是模拟用户环境：
    - 假 Nexus：编译一个什么都不做的小程序，放到 Nexus 默认安装位置，并用 reg add 造一份 Dock 配置
    - 假 Wallpaper Engine：Steam 路径、wallpaper32.exe、config.json 和水墨壁纸的 project.json
    - 已有同名计划任务 WallpaperEngine_Logon（指向记事本）

  需要环境变量 RICE_DIRECT=1（见 scripts/common.ps1 开头）：不依赖虚拟机上的 Explorer 转交。
#>
$ErrorActionPreference = 'Stop'

if ($env:GITHUB_ACTIONS -ne 'true') {
    Write-Host '这个测试会修改当前用户的桌面设置，只在 GitHub Actions 虚拟机上运行。已停止，什么都没改。'
    exit 1
}
if ($env:RICE_DIRECT -ne '1') {
    Write-Host '需要设置环境变量 RICE_DIRECT=1（虚拟机上不经 Explorer 转交）。'
    exit 1
}
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) }
catch { Write-Verbose "无法设置控制台编码：$($_.Exception.Message)" }

$root      = Split-Path $PSScriptRoot
$backupDir = Join-Path $root 'backup'
$work      = Join-Path ([IO.Path]::GetTempPath()) ('rice-roundtrip-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null

$taskName  = 'WallpaperEngine_Logon'
$nexusDir  = "${env:ProgramFiles(x86)}\Winstep"
$nexusExe  = Join-Path $nexusDir 'Nexus.exe'
$steamDir  = 'C:\FakeSteam'
$weDir     = Join-Path $steamDir 'steamapps\common\wallpaper_engine'
$weExe     = Join-Path $weDir 'wallpaper32.exe'
$weConfig  = Join-Path $weDir 'config.json'
$iconDir   = Join-Path $env:APPDATA 'NexusDock\win11-desktop-rice-icons'
$docksKey  = 'HKCU:\Software\WinSTEP2000\NeXuS\Docks'
$stuckRects = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'

# 参与对比的注册表：路径、是否包含子键
$snapshotKeys = @(
    @{ Path = 'HKCU:\Software\WinSTEP2000\NeXuS'; Recurse = $true }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Recurse = $false }
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Recurse = $false }
    @{ Path = $stuckRects; Recurse = $false }
    # 桌面视图的「不显示图标」位，资源管理器启动时据此改写 HideIcons；其余值随图标位置变化，不比较
    @{ Path = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'; Recurse = $false; Only = 'FFlags' }
)
# 运行时会自己变化、与脚本无关的值（「键\值名」的正则）。
# 假 Nexus 不写注册表，所以 NeXuS 下暂时没有要排除的；换成真 Nexus 测试时在这里补充。
$volatileValues = @(
    '\\Explorer\\Advanced\\TaskbarStateLastRun$'   # 资源管理器每次启动写入的时间戳
)

$failures = 0
function Assert-Condition([bool]$Condition, [string]$Message) {
    if ($Condition) { Write-Host "  通过：$Message" }
    else { Write-Host "  失败：$Message"; $script:failures++ }
}

function Write-Section([string]$title) { Write-Host "`n==================== $title ====================" }

# reg.exe 的成功提示写在错误输出，交给 cmd 执行，只看退出码
function Invoke-Reg([string]$arguments) {
    cmd /c "reg $arguments >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "reg $arguments 失败：$LASTEXITCODE" }
}

# 像用户一样在新的 PowerShell 5.1 进程里运行仓库脚本；输出按 UTF-8 存文件，避免中文乱码。
function Invoke-RepoScript([string]$Script, [string]$Arguments = '') {
    $log = Join-Path $work ('run-' + [guid]::NewGuid().ToString('N') + '.log')
    $path = Join-Path $root $Script
    Write-Host "`n>>> $Script $Arguments"
    $command = "& '$path' $Arguments *>&1 | Out-File -LiteralPath '$log' -Encoding utf8 -Width 240; exit `$LASTEXITCODE"
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command $command
    $code = $LASTEXITCODE
    $text = if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Raw -Encoding UTF8 } else { '' }
    Write-Host $text
    Write-Host "<<< 退出码：$code"
    return [pscustomobject]@{ Code = $code; Text = $text }
}

# 结果表里每个步骤都应是预期结果（如「成功」「完成」）
function Assert-StepTable($run, [string[]]$Steps, [string]$Expected) {
    foreach ($step in $Steps) {
        $ok = $run.Text -match ('(?m)^' + [regex]::Escape($step) + '\s+' + [regex]::Escape($Expected))
        Assert-Condition $ok "结果表：$step = $Expected"
    }
}

function Get-RegistryLine([string]$Path, [bool]$Recurse, [string]$Only) {
    if (-not (Test-Path $Path)) { return "$Path <不存在>" }
    $keys = @(Get-Item $Path)
    if ($Recurse) { $keys += @(Get-ChildItem $Path -Recurse) }
    foreach ($key in $keys) {
        "$($key.Name)\"
        foreach ($name in $key.GetValueNames()) {
            if ($Only -and $name -ne $Only) { continue }
            $id = "$($key.Name)\$name"
            if ($volatileValues | Where-Object { $id -match $_ }) { continue }
            $value = $key.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
            $text = if ($value -is [byte[]]) { ($value | ForEach-Object { $_.ToString('x2') }) -join ',' }
                    elseif ($value -is [array]) { $value -join '|' }
                    else { [string]$value }
            "$id [$($key.GetValueKind($name))] = $text"
        }
    }
}

# 当前状态快照：注册表、计划任务 XML、Wallpaper Engine 配置的哈希
function Get-Snapshot {
    $lines = foreach ($k in $snapshotKeys) { Get-RegistryLine $k.Path $k.Recurse $k.Only }
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        $lines += (Export-ScheduledTask -TaskName $taskName) -split "`r?`n" | ForEach-Object { "任务XML: $_" }
    } else {
        $lines += '任务XML: <不存在>'
    }
    $lines += "config.json SHA256 = $((Get-FileHash -LiteralPath $weConfig -Algorithm SHA256).Hash)"
    return @($lines | Sort-Object)
}

function Assert-SameSnapshot([string[]]$Expected, [string]$Message) {
    $actual = Get-Snapshot
    $diff = @(Compare-Object -ReferenceObject $Expected -DifferenceObject $actual -CaseSensitive)
    if ($diff.Count -gt 0) {
        Write-Host "  差异（<= 基准独有，=> 现在独有）："
        $diff | ForEach-Object { Write-Host ("    {0} {1}" -f $_.SideIndicator, $_.InputObject) }
    }
    Assert-Condition ($diff.Count -eq 0) "$Message（$($diff.Count) 处差异）"
}

function Test-FakeRunning([string]$name, [string]$directory) {
    return [bool](Get-Process -Name $name -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and (Split-Path $_.Path) -eq $directory })
}

# 诊断：桌面图标显示状态的两处记录（HideIcons 与桌面视图 FFlags），以及资源管理器进程
function Write-DesktopState([string]$when) {
    $hide = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -ErrorAction SilentlyContinue).HideIcons
    $flags = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop' -ErrorAction SilentlyContinue).FFlags
    $explorer = (Get-Process -Name explorer -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Id)/会话$($_.SessionId)" }) -join '、'
    Write-Host ("  [诊断 {0}] HideIcons={1} FFlags={2} 资源管理器={3}" -f $when, $hide, $(if ($null -ne $flags) { '0x{0:x}' -f $flags }), $explorer)
}

function Get-DockValue([string]$name) { return (Get-Item $docksKey).GetValue($name) }

function Clear-Backup {
    if (Test-Path $backupDir) { Remove-Item -LiteralPath $backupDir -Recurse -Force }
}

# 首次安装生成、重复安装不得改动的备份文件
function Get-BackupHash {
    $hashes = @{}
    Get-ChildItem -LiteralPath $backupDir -File | Where-Object { $_.Name -notlike 'winstep-before-change-*' } |
        ForEach-Object { $hashes[$_.Name] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    return $hashes
}

function New-OriginalTask {
    $action  = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\notepad.exe" -Argument 'C:\原来的任务.txt'
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description '测试：用户原来就有的同名任务' -Force | Out-Null
}

try {
    # ---------------------------------------------------------------
    Write-Section '模拟用户环境'
    Write-Host "用户：$env:USERNAME，会话：$((Get-Process -Id $PID).SessionId)，PowerShell：$($PSVersionTable.PSVersion)"
    Get-Process -Name explorer -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "资源管理器 PID $($_.Id)，会话 $($_.SessionId)" }

    # 假程序：带参数（壁纸控制命令）立即返回 0，否则一直运行，像常驻程序一样等着被结束
    $fakeExe = Join-Path $work 'fake-app.exe'
    Add-Type -OutputType WindowsApplication -OutputAssembly $fakeExe -TypeDefinition @'
public static class FakeApp {
    public static int Main(string[] args) {
        if (args.Length > 0) { return 0; }
        System.Threading.Thread.Sleep(System.Threading.Timeout.Infinite);
        return 0;
    }
}
'@
    New-Item -ItemType Directory -Force $nexusDir, $weDir | Out-Null
    Copy-Item -LiteralPath $fakeExe -Destination $nexusExe -Force
    Copy-Item -LiteralPath $fakeExe -Destination $weExe -Force

    # 假 Nexus 配置：3 个软件，最后序号 DockNoItems1 = 2；根键放几项和导入值不同的外观设置
    $apps = @(
        @{ Label = '资源管理器'; Path = "$env:WINDIR\explorer.exe" }
        @{ Label = '记事本';     Path = "$env:WINDIR\System32\notepad.exe" }
        @{ Label = '注册表 编辑器'; Path = "$env:WINDIR\regedit.exe" }
    )
    foreach ($a in $apps) { if (-not (Test-Path $a.Path)) { throw "模拟用的程序不存在：$($a.Path)" } }
    $docks = 'HKCU\Software\WinSTEP2000\NeXuS\Docks'
    for ($i = 0; $i -lt $apps.Count; $i++) {
        $a = $apps[$i]
        Invoke-Reg "add `"$docks`" /v 1Path$i /t REG_SZ /d `"$($a.Path)`" /f"
        Invoke-Reg "add `"$docks`" /v 1Label$i /t REG_SZ /d `"$($a.Label)`" /f"
        Invoke-Reg "add `"$docks`" /v 1IconPath$i /t REG_SZ /d `"$($a.Path)`" /f"
        Invoke-Reg "add `"$docks`" /v 1StartPath$i /t REG_SZ /d `"$(Split-Path $a.Path)\\`" /f"
        Invoke-Reg "add `"$docks`" /v 1Type$i /t REG_SZ /d 1 /f"
    }
    Invoke-Reg "add `"$docks`" /v DockNoItems1 /t REG_SZ /d 2 /f"
    Invoke-Reg "add `"$docks`" /v DockIconSize1 /t REG_SZ /d 40 /f"
    Invoke-Reg "add `"HKCU\Software\WinSTEP2000\NeXuS`" /v NeXuSAlphaThreshold /t REG_SZ /d 32 /f"
    Invoke-Reg "add `"HKCU\Software\WinSTEP2000\NeXuS`" /v NexusAccentColorHotTrack /t REG_SZ /d True /f"
    Invoke-Reg "add `"HKCU\Software\WinSTEP2000\NeXuS`" /v TestDword /t REG_DWORD /d 7 /f"
    # 主题文件夹存在时脚本才会写主题项，让这条分支也被测到
    New-Item -ItemType Directory -Force (Join-Path ([Environment]::GetFolderPath('CommonDocuments')) 'WinStep\Themes\windows10nx') | Out-Null

    # 没登录过桌面的账户可能没有任务栏设置，按常见 Win11 值补一份（第 9 字节 2 = 常驻）
    if (-not (Test-Path $stuckRects)) {
        Write-Host '没有 StuckRects3，创建一份模拟值。'
        New-Item -Path $stuckRects -Force | Out-Null
        $bytes = [byte[]](0x30,0,0,0,0xfe,0xff,0xff,0xff,2,0,0,0,3,0,0,0,0x30,0,0,0,0x30,0,0,0,0,0,0,0,0x08,0x04,0,0,0x80,0x07,0,0,0x38,0x04,0,0,0x60,0,0,0,1,0,0,0)
        New-ItemProperty -Path $stuckRects -Name Settings -PropertyType Binary -Value $bytes | Out-Null
    }

    # 假 Steam 和 Wallpaper Engine
    Invoke-Reg "add `"HKCU\Software\Valve\Steam`" /v SteamPath /t REG_SZ /d `"c:/fakesteam`" /f"
    [IO.File]::WriteAllText($weConfig, '{"user":{"general":{"wallpaperconfig":{"selectedwallpapers":{"Monitor0":{"file":"C:/原来的壁纸/project.json"}}}}}}', [Text.UTF8Encoding]::new($false))
    $project = Join-Path $steamDir 'steamapps\workshop\content\431960\3073167683\project.json'
    New-Item -ItemType Directory -Force (Split-Path $project) | Out-Null
    [IO.File]::WriteAllText($project, '{"title":"ink"}')

    # 用户电脑上 Nexus 和壁纸都在运行
    Start-Process -FilePath $nexusExe -WorkingDirectory $nexusDir
    Start-Process -FilePath $weExe -WorkingDirectory $weDir
    Start-Sleep -Seconds 2
    Assert-Condition (Test-FakeRunning 'Nexus' $nexusDir) '假 Nexus 正在运行'
    Assert-Condition (Test-FakeRunning 'wallpaper32' $weDir) '假 Wallpaper Engine 正在运行'

    $prepare = Invoke-RepoScript 'scripts\prepare.ps1'
    Assert-Condition ($prepare.Code -eq 0) 'prepare.ps1 认为环境就绪（退出码 0）'

    # ---------------------------------------------------------------
    Write-Section '场景 1：已有同名计划任务，-Yes -KeepMyApps -Style ink'
    New-OriginalTask
    Clear-Backup
    $baseline = Get-Snapshot
    Write-DesktopState '基准'
    $dockBefore = @($baseline | Where-Object { $_ -match '\\Docks\\(1(Path|Label|StartPath|Type)\d+|DockNoItems1) ' })
    Write-Host "基准共 $($baseline.Count) 行，Dock 软件相关 $($dockBefore.Count) 行。"

    $run = Invoke-RepoScript 'install.ps1' '-Yes -KeepMyApps -Style ink'
    Assert-Condition ($run.Code -eq 0) 'install.ps1 退出码 0'
    Write-DesktopState '安装后'
    Assert-StepTable $run @('1/3 调整任务栏和桌面', '2/3 导入 Nexus Dock', '3/3 Wallpaper Engine 开机自启', '切换壁纸风格') '成功'

    $advanced = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Assert-Condition ($advanced.HideIcons -eq 1) '已隐藏桌面图标'
    Assert-Condition ((Get-ItemProperty $stuckRects).Settings[8] -eq 3) '任务栏已设为自动隐藏'
    Assert-Condition ((Get-DockValue 'DockHideControlIcon1') -eq 'True') '已导入 Dock 外观（隐藏 NeXuS 标志）'
    $dockAfter = @(Get-Snapshot | Where-Object { $_ -match '\\Docks\\(1(Path|Label|StartPath|Type)\d+|DockNoItems1) ' })
    Assert-Condition ((@(Compare-Object $dockBefore $dockAfter -CaseSensitive)).Count -eq 0) '保留了全部 3 个软件，序号和路径没变（没丢图标）'
    $action = (Get-ScheduledTask -TaskName $taskName).Actions[0].Execute
    Assert-Condition ($action -eq $weExe) "计划任务已指向 Wallpaper Engine（$action）"
    Assert-Condition (Test-FakeRunning 'Nexus' $nexusDir) '安装后 Nexus 仍在运行'
    Assert-Condition (Test-FakeRunning 'wallpaper32' $weDir) '安装后 Wallpaper Engine 仍在运行'
    $expectedBackups = 'look-backup.json', 'nexus-backup.reg', 'wallpaper-task-backup.xml', 'wallpaper-config-backup.json', 'wallpaper-style-backup.json'
    foreach ($f in $expectedBackups) { Assert-Condition (Test-Path (Join-Path $backupDir $f)) "已生成备份 $f" }
    Assert-Condition (-not (Test-Path (Join-Path $backupDir 'wallpaper-task-created.txt'))) '原有任务不会被当成本工具新建'

    Write-Host "`n-- 重复安装，备份不应被覆盖 --"
    $firstBackups = Get-BackupHash
    $run = Invoke-RepoScript 'install.ps1' '-Yes -KeepMyApps -Style ink'
    Assert-Condition ($run.Code -eq 0) '重复安装退出码 0'
    $secondBackups = Get-BackupHash
    foreach ($name in $firstBackups.Keys) {
        Assert-Condition ($secondBackups[$name] -eq $firstBackups[$name]) "重复安装后 $name 未被覆盖"
    }

    $run = Invoke-RepoScript 'restore.ps1'
    Assert-Condition ($run.Code -eq 0) 'restore.ps1 退出码 0'
    foreach ($s in 0, 3, 6) { Start-Sleep -Seconds $s; Write-DesktopState "还原后+$s 秒" }
    Assert-StepTable $run @('还原壁纸和 Wallpaper Engine 配置', '还原任务栏和桌面', '还原 Nexus Dock', '还原 Wallpaper Engine 自启') '完成'
    Assert-SameSnapshot $baseline '还原后与安装前 0 差异'
    Assert-Condition (-not (Test-Path $iconDir)) '已删除生成的图标文件夹'
    foreach ($f in $expectedBackups + 'wallpaper-config-before-undo.json', 'nexus-before-undo.reg') {
        Assert-Condition (-not (Test-Path (Join-Path $backupDir $f))) "还原后已清理 $f"
    }
    Assert-Condition (Test-FakeRunning 'Nexus' $nexusDir) '还原后 Nexus 在运行'
    Assert-Condition (Test-FakeRunning 'wallpaper32' $weDir) '还原后 Wallpaper Engine 在运行'

    # ---------------------------------------------------------------
    Write-Section '场景 2：没有同名计划任务，-Yes -ReplaceApps'
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Clear-Backup
    $baseline = Get-Snapshot

    $run = Invoke-RepoScript 'install.ps1' '-Yes -ReplaceApps'
    Assert-Condition ($run.Code -eq 0) 'install.ps1 退出码 0'
    Assert-StepTable $run @('1/3 调整任务栏和桌面', '2/3 导入 Nexus Dock', '3/3 Wallpaper Engine 开机自启') '成功'
    Assert-Condition ((Get-DockValue '1Label0') -eq '文件资源管理器') 'Dock 已换成检测到的常用软件'
    $paths = (Get-Item $docksKey).GetValueNames() | Where-Object { $_ -match '^1Path\d+$' } | ForEach-Object { Get-DockValue $_ }
    Assert-Condition (-not ($paths -contains "$env:WINDIR\regedit.exe")) '原来的软件已被替换'
    Assert-Condition (Test-Path (Join-Path $backupDir 'wallpaper-task-created.txt')) '新建任务留下了标记'
    Assert-Condition (Test-FakeRunning 'Nexus' $nexusDir) '安装后 Nexus 仍在运行'

    $run = Invoke-RepoScript 'restore.ps1'
    Assert-Condition ($run.Code -eq 0) 'restore.ps1 退出码 0'
    Assert-StepTable $run @('还原壁纸和 Wallpaper Engine 配置', '还原任务栏和桌面', '还原 Nexus Dock', '还原 Wallpaper Engine 自启') '完成'
    Assert-SameSnapshot $baseline '还原后与安装前 0 差异（含删除新建的计划任务）'
    Assert-Condition (-not (Test-Path $iconDir)) '已删除生成的图标文件夹'

    # ---------------------------------------------------------------
    Write-Section '场景 3：Nexus 备份损坏，还原必须失败且不改注册表'
    $corrupt = Join-Path $backupDir 'nexus-backup.reg'

    Write-Host "`n-- 3a 备份缺少 NeXuS 键（截断的文件） --"
    Clear-Backup
    New-Item -ItemType Directory -Force $backupDir | Out-Null
    [IO.File]::WriteAllText($corrupt, "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_CURRENT_USER\Software\WinSTEP2000", [Text.Encoding]::Unicode)
    $before = Get-Snapshot
    $run = Invoke-RepoScript 'restore.ps1'
    Assert-Condition ($run.Code -ne 0) "restore.ps1 退出码非 0（$($run.Code)）"
    Assert-StepTable $run @('还原 Nexus Dock') '失败'
    Assert-SameSnapshot $before '注册表和任务未被改动'
    Assert-Condition (Test-Path $corrupt) '损坏的备份保留未删'
    Assert-Condition (Test-FakeRunning 'Nexus' $nexusDir) 'Nexus 仍在运行'

    Write-Host "`n-- 3b 备份有 NeXuS 键但不是注册表文件（导入失败，走回滚） --"
    Clear-Backup
    New-Item -ItemType Directory -Force $backupDir | Out-Null
    [IO.File]::WriteAllText($corrupt, "这不是注册表文件`r`n[HKEY_CURRENT_USER\Software\WinSTEP2000\NeXuS]`r`n`"x`"=", [Text.Encoding]::Unicode)
    $before = Get-Snapshot
    $run = Invoke-RepoScript 'restore.ps1'
    Assert-Condition ($run.Code -ne 0) "restore.ps1 退出码非 0（$($run.Code)）"
    Assert-StepTable $run @('还原 Nexus Dock') '失败'
    Assert-SameSnapshot $before '回滚后注册表和任务未被改动'
    Assert-Condition (Test-Path $corrupt) '损坏的备份保留未删'
    Assert-Condition (Test-FakeRunning 'Nexus' $nexusDir) '回滚后 Nexus 重新运行'
} catch {
    Write-Host "测试中断：$($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace
    $failures++
} finally {
    Get-Process -Name Nexus, wallpaper32 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Clear-Backup
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Section '结论'
if ($failures -gt 0) { Write-Host "有 $failures 项检查失败，见上面的「失败」和差异。"; exit 1 }
Write-Host '全部通过。'
exit 0
