# 不改真实桌面：验证 Explorer 工作进程的输出和非零退出码能回传。
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\scripts\common.ps1"
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('rice-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir | Out-Null
try {
    $testScript = Join-Path $testDir '中文 exit-code.ps1'
    [IO.File]::WriteAllText($testScript, 'param([switch]$Enabled); if (-not $Enabled) { exit 3 }; Write-Output "桌面工作进程已执行"; exit 7', [Text.UTF8Encoding]::new($true))
    $code = Invoke-DesktopScript -ScriptPath $testScript -Parameters @{ Enabled = $true }
    if ($code -ne 7) { throw "工作进程退出码丢失：$code" }
    [IO.File]::WriteAllText($testScript, 'throw "工作进程预期错误"', [Text.UTF8Encoding]::new($true))
    $code = Invoke-DesktopScript -ScriptPath $testScript
    if ($code -ne 1) { throw "工作进程异常没有返回失败：$code" }
    $rejected = $false
    try { Start-Detached -FilePath (Join-Path $testDir 'missing.exe') -ProcessName missing }
    catch {
        if ($_.Exception.Message -notlike '*找不到程序*missing.exe*') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw '未拒绝不存在的程序' }
    Write-Host '回归检查通过：中文空格路径、开关参数、退出码、工作进程异常、缺失程序错误。'
} finally {
    Remove-Item -LiteralPath $testDir -Recurse -Force
}
