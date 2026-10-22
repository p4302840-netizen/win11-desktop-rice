# 给 AI 的桌面安装说明

目标：在当前用户的 Windows 11 桌面上应用任务栏、Nexus Dock 和 Wallpaper Engine 风格。用户说「帮我安装」时，按下面顺序执行并检查结果，遇到必须由用户处理的步骤就暂停该步骤。

## 安全边界

- 使用普通用户终端，不要以管理员身份运行，不自动批准 UAC，不切换账户。
- 脚本只修改当前用户的桌面设置；软件安装仅通过明确的 `-InstallNexus` 进行。若安装器要求提权，让用户处理，不自行提权。
- 不删除用户文件，不清空 Dock 软件列表；默认选择 `-KeepMyApps`。只有用户明确要求替换列表时才使用 `-ReplaceApps`。
- 改动前保留仓库 `backup/`；已有备份不覆盖，不提交或上传含私人路径的备份。
- 付款、购买 Wallpaper Engine、账户登录、在 Steam 点「订阅」均必须停下来让用户亲自操作。不要代买、代付、输入凭据或自动点订阅。
- 没有验证实际画面之前，不报告「桌面安装成功」。所有 `.ps1` 保持 UTF-8 带 BOM。

## 推荐顺序

先在仓库根目录检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare.ps1
```

检查表两项「就绪」为 True 且退出码 0 才继续。退出码 2 表示缺少需要用户处理的条件；1 表示检查或安装出错。缺少 Nexus 时，可用下面的显式选项安装免费软件；它会启动 Nexus 并最多等 60 秒，等待当前用户的 Docks 注册表键出现：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare.ps1 -InstallNexus
```

缺少 Wallpaper Engine 时，告诉用户需要自己购买：`steam://store/431960`。用户已购买时请其打开 `steam://install/431960` 安装。脚本不能判断购买状态。首次打开 Wallpaper Engine 后选择一张壁纸并退出一次，让它保存 `config.json`。请用户在设置里关闭「高优先级」；未确认其配置字段，不要猜测字段或修改 Windows 服务。

软件就绪后，安装外观并保留 Dock 上的软件：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Yes -KeepMyApps
powershell -ExecutionPolicy Bypass -File .\scripts\set-style.ps1 -Style ink
```

风格：`landscape` 风景、`ink` 水墨、`cyber` 赛博朋克。也可合并成 `install.ps1 -Yes -KeepMyApps -Style ink`，此时不必再单独切换。

`install.ps1` 无参数仍交互提问；`-Yes` 跳过全部脚本提问，未指定 Dock 策略时保留现有软件。`-KeepMyApps` / `-ReplaceApps` 互斥。

壁纸未下载时，切换脚本会打开对应 Steam 页面，显示提示并最多等待 3 分钟；订阅必须由用户点击。用 `-NoWait` 可在打开页面后立即返回 2，然后等用户完成订阅和下载再重试。脚本检测所有 Steam 库中的 `project.json`，不能保证 Steam 已完成全部资源下载。

## 怎么判断成功

- 受控环境（如打包的桌面 AI 应用）里的 HKCU 可能被隔离，脚本已自动转交桌面进程；验证时请以 Explorer 视图为准（可用 reg export 经 explorer 启动的批处理读取）。
- 每次外部 PowerShell 命令结束后检查 `$LASTEXITCODE`，不要把打开链接或看到输出当成成功。
- 安装结果表每个预期步骤应为「成功」；「跳过」表示未完成该项，即便整体退出码为 0 也不能宣称全装好了。1 表示执行失败，2 表示风格步骤需要用户处理；混合错误优先返回 1。
- 风格脚本的 0 仅表示控制命令正常返回，2 表示缺少软件、配置或下载，1 表示备份、进程或命令失败。
- 查看实际桌面：任务栏行为、Dock 现有软件与隐藏 NeXuS 标志、选定壁纸、各显示器都要核对。新版流程尚待真机验证，不能沿用旧版的测试结论。

## 出错与还原

先记录失败步骤和原始错误，不反复盲跑。需要撤销时：

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

退出码 0 且各项「完成」后仍要核对画面；失败为 1，对应备份保留，可修复后重试。还原涵盖外观、Nexus、壁纸自启任务，以及首次切风格前保存的完整 Wallpaper Engine 配置。恢复配置会关闭当前会话中的引擎并重新启动，之后手动修改的 Wallpaper Engine 设置也会回退。原壁纸资源若已删除或取消订阅，需要用户重新下载。高优先级未自动修改，无需脚本恢复；软件安装、购买及订阅不由还原脚本撤销。
