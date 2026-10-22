# 只解析源码，不执行 apply/export 脚本或访问真实桌面注册表。
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
function Read-Ast([string]$relative) {
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative), [ref]$null, [ref]$errors)
    if ($errors) { throw "$relative 语法错误：$errors" }
    return $ast
}
function Assert($condition, [string]$message) {
    if (-not $condition) { throw $message }
}

$look = Read-Ast 'scripts/apply-look.ps1'
$desktopParameter = @($look.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'DesktopSession' })
Assert ($desktopParameter.Count -eq 1) 'apply-look 缺少 DesktopSession 防循环开关'
Assert ($desktopParameter[0].StaticType -eq [switch]) 'DesktopSession 必须是开关'
$hidden = @($desktopParameter[0].Attributes.NamedArguments | Where-Object { $_.ArgumentName -eq 'DontShow' -and $_.Argument.SafeGetValue() -eq $true })
Assert ($hidden.Count -eq 1) 'DesktopSession 必须隐藏'

# 转交必须紧随 common.ps1 加载，早于备份路径、HKCU 读取和所有事务分支。
$statements = $look.EndBlock.Statements
$guard = $statements[2]
Assert ($guard -is [System.Management.Automation.Language.IfStatementAst]) '外观事务之前必须先转交桌面进程'
Assert ($guard.Clauses[0].Item1.Extent.Text -eq '-not $DesktopSession') '桌面工作进程不得再次转交'
$invoke = @($guard.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Invoke-DesktopScript' }, $true))
Assert ($invoke.Count -eq 1) '外观应用和 Undo 必须统一通过 Invoke-DesktopScript'
$elements = $invoke[0].CommandElements
Assert ($elements[2].Extent.Text -eq '$PSCommandPath') '必须转交当前完整脚本'
$parameters = $elements[4]
Assert ($parameters -is [System.Management.Automation.Language.HashtableAst]) '转交参数必须明确列出'
$forward = @{}
foreach ($pair in $parameters.KeyValuePairs) { $forward[$pair.Item1.SafeGetValue()] = $pair.Item2.Extent.Text }
Assert ($forward.Undo -eq '[bool]$Undo') 'Undo 必须传给桌面工作进程'
Assert ($forward.DesktopSession -eq '$true') '工作进程必须设置防循环标记'
$exits = @($guard.FindAll({ param($node) $node -is [System.Management.Automation.Language.ExitStatementAst] }, $true) | ForEach-Object { $_.Pipeline.Extent.Text })
Assert ($exits -contains '$code') '调用方必须返回工作进程退出码并停止本地事务'
Assert ($exits -contains '1') '桌面转交异常必须返回失败并停止本地事务'
Write-Host '通过：外观完整事务转交、Undo、防循环和退出码（静态 AST）。'

$export = Read-Ast 'scripts/export-nexus.ps1'
$skipAssignment = $export.Find({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$skip' }, $true)
$skip = $skipAssignment.Right.Expression.SafeGetValue()
Assert ($skip -contains 'DockNoItems1') '导出必须排除作者的最后图标序号 DockNoItems1'
$config = Get-Content -LiteralPath (Join-Path $root 'config/nexus-dock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert (-not ($config.dock.PSObject.Properties.Name -contains 'DockNoItems1')) '共享外观配置不得包含 DockNoItems1'
Write-Host '通过：导出过滤名单及共享配置均排除 DockNoItems1。'
