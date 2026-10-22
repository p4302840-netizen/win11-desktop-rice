# PSScriptAnalyzer 检查规则。CI 和本地检查都用这份配置。
@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',                        # 这些脚本是给人看的，就是要往屏幕上打印中文提示
        'PSUseShouldProcessForStateChangingFunctions',  # 脚本内部的小工具函数，不需要 -WhatIf
        'PSUseSingularNouns'                            # Get-SteamLibraries 返回多个库，复数更准确
    )
}
