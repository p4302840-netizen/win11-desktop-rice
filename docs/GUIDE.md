# 安装与使用

[← 返回首页](../README.md) · [看演示](DEMO.md)

### 准备条件

- **两款软件**：Wallpaper Engine（Steam 付费，常年打折）和 Winstep Nexus（免费）。
- **脚本负责**：设置任务栏和桌面、导入 Dock 外观和图标列表、设置壁纸登录后自动启动。
- **你来完成**：安装两款软件，先打开一次 Nexus；订阅并选择壁纸，在 Wallpaper Engine 里取消「高优先级」。

也可让 AI 按 [AGENTS.md](../AGENTS.md) 操作；新流程的参数见下文。购买、登录、付款和 Steam 订阅仍由用户亲自完成。

## 安装后会得到什么

| 方式 | 内容 |
| --- | --- |
| 自动设置 | 任务栏改成深色并自动隐藏，鼠标移到屏幕最底部才出现；隐藏桌面图标，让壁纸完整露出来 |
| 自动导入 | 导入外观（底部居中、划过放大、倒影、运行指示点），图标列表按最后一行的选择处理。 |
| 自动设置 | Wallpaper Engine 登录后 10 秒自动启动；原来有同名自启任务时，会先完整备份 |
| 手动完成 | 从 [14 张精选壁纸](../wallpapers.md)中订阅并选择喜欢的水墨、赛博朋克、动漫或风景壁纸；取消「高优先级」 |
| 按你的选择和检测结果 | 保留 Dock 现有软件（推荐），或换成自动检测到的常用软件；只查下列 8 款的常见安装位置 |

常用软件列表：资源管理器、Edge、Chrome、QQ、微信、Steam、QQ 音乐、网易云音乐。图标从你电脑上的软件里提取，统一视觉大小，不需要下载。

## 开始安装

> [!IMPORTANT]
> 所有脚本只改**当前用户**的设置，**不需要管理员权限**。请不要「以管理员身份运行」：如果平时用的不是管理员账户，用别的账户提权会改到那个账户的设置。

### 1. 安装软件，下载仓库

安装 [Wallpaper Engine（Steam）](https://store.steampowered.com/app/431960/Wallpaper_Engine/) 和 [Winstep Nexus（官网）](https://www.winstep.net/nexus.htm)。装完 Nexus 后**先打开一次**，等底部出现 Dock 再继续。

点页面上方绿色的 **Code → Download ZIP**，解压到任意位置。

### 2. 运行安装脚本

在解压出来的文件夹里，**按住 Shift + 右键空白处** →「在终端中打开」，粘贴并回车：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会先检查软件是否安装，问你一次确认，再依次设置任务栏和桌面、导入 Dock、设置壁纸自启。导入 Dock 时会让你选择**保留现有软件**（推荐）或**换成常用软件**。

全程大约 10 秒，任务栏和 Dock 会闪一下。最后会列出每一步是「成功」「跳过」还是「失败」，某一步失败不会影响其他步骤。

改动前会自动备份到仓库里的 `backup\` 文件夹，**还原前请不要删除它**。

### 3. 选择壁纸，关闭高优先级

打开 **[壁纸画廊](../wallpapers.md)**，点喜欢的那张，在 Steam 页面点「订阅」，然后在 Wallpaper Engine 里选中它。

在 Wallpaper Engine 设置里**取消勾选「高优先级」**，否则它会切回依赖后台服务启动的模式。

## AI 安装与新参数（v1.2.0，尚待真机验证）

推荐先检查、再安装、最后切风格：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare.ps1
# 缺少 Nexus 时才显式安装，并启动一次等待初始化：
powershell -ExecutionPolicy Bypass -File .\scripts\prepare.ps1 -InstallNexus
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Yes -KeepMyApps
powershell -ExecutionPolicy Bypass -File .\scripts\set-style.ps1 -Style ink
```

| 脚本与参数 | 含义 |
| --- | --- |
| `prepare.ps1` | 默认只读，结果表检查 Nexus 程序及 Docks 配置、Wallpaper Engine 程序 |
| `prepare.ps1 -InstallNexus` | 仅缺少 Nexus 时调用 winget 安装；未初始化时启动 Nexus，最多等 60 秒。无 winget、安装失败返回 1 |
| `install.ps1 -Yes` | 跳过确认及 Dock 问答；默认保留现有软件 |
| `-KeepMyApps` / `-ReplaceApps` | 保留软件并统一样式 / 换成检测到的常用软件，不能同时指定；不用 `-Yes` 仍会问总确认 |
| `install.ps1 -Yes -KeepMyApps -Style ink` | 安装后调用切风格脚本，可代替最后两条命令 |
| `set-style.ps1 -Style landscape\|ink\|cyber` | 风景 `3683255353`、水墨 `3073167683`、赛博朋克 `2447094306` |
| `set-style.ps1 -Style ink -NoWait` | 壁纸未下载时打开 Steam 订阅页后立即返回 2，不轮询 |

Wallpaper Engine 未安装时仅提供 `steam://store/431960` 并说明需要用户自己购买；已购买的用户可用 `steam://install/431960` 安装，不自动购买或判断所有权。首次启动并选择壁纸、退出一次以保存配置后再切换。

未下载壁纸时会打开 `steam://url/CommunityFilePage/<ID>`，由用户点「订阅」。默认每 5 秒在所有 Steam 库下查一次，最多 3 分钟；要求 `steamapps/workshop/content/431960/<ID>/project.json` 存在且可解析。文件夹/描述文件出现不保证全部媒体已下载，需检查 Steam 下载和实际画面，超时后可重试。

`prepare.ps1`：0 全部就绪，2 需要用户处理，1 执行错误。`set-style.ps1`：0 控制命令正常返回，2 缺少软件、保存的配置或下载，1 操作失败。`install.ps1`：1 有执行错误，2 仅风格步骤需用户处理；无参数时沿用原来的交互和跳过逻辑。**检查 `$LASTEXITCODE` 和结果表，并核对画面；「跳过」不等于完成，切换命令返回 0 也不证明渲染成功。**

高优先级的可靠 `config.json` 字段未确认，脚本不会自动关闭它或修改服务。[官方说明](https://help.wallpaperengine.io/en/functionality/automaticstartup.html)确认该选项注册 Windows 服务；请用户在界面中关闭。切换使用[官方命令行控制](https://help.wallpaperengine.io/en/functionality/cli.html)的 `openWallpaper -file`。

切换前会结束当前会话、安装目录内的 Wallpaper Engine 引擎和界面，备份磁盘上最后保存的完整 `config.json` 到 `backup/wallpaper-config-backup.json`。`wallpaper-style-backup.json` 保存安装路径、SHA256 及配置中识别到的壁纸/资源路径清单；它不是实时查询接口，未保存的界面改动不包含在内。重复切换保留首次快照。

交付后的真机验证建议覆盖：无参数交互、`-Yes` 保留与替换两种策略、缺软件/首次初始化、Steam 非默认库、未订阅与超时、路径含空格、连续切换后还原、损坏备份、多显示器及高优先级仍开启的情况。不要把旧版兼容性记录当成本版验证结果。

## 换成你自己的样子

- **增添软件**：把游戏或软件拖到 Dock 上；安装时选择「保留现有软件」，可以保留自己的列表并统一图标大小。
- **更换壁纸**：去 [壁纸画廊](../wallpapers.md)订阅并选择另一张；不用的壁纸在 Wallpaper Engine 里右键 →「取消订阅」。
- **调整大小**：右键 Dock → **Preferences**。当前图标为 48 px，鼠标划过放大到 128 px；主题、间距、倒影等完整参数见 [Dock 配置](DOCK.md)。

调好后可以运行 `scripts\export-nexus.ps1` 分享自己的 Dock 外观，不会带上软件路径、天气城市等个人信息。

## 还原

在仓库文件夹里运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

还原范围是 `backup\` 中备份的脚本改动：

- 任务栏和桌面的 5 项设置恢复成原来的值。
- Nexus 配置整块恢复；恢复前先另存当前配置，万一失败会自动退回。
- Wallpaper Engine 自启任务：原来就有的恢复原设置，原来没有的删掉。
- 壁纸与完整 Wallpaper Engine 配置：关闭当前会话中的引擎，校验并恢复首次切换快照，再重新启动。恢复前另存 `backup/wallpaper-config-before-undo.json`；失败时保留备份。后续手动调整的引擎设置也会回退；已删除或取消订阅的原壁纸资源需要用户重新下载。

还原不卸载软件、不撤销购买或订阅；高优先级未被脚本改动。备份含本机路径，请勿上传。

某一步没还原成功，会显示「失败」，对应备份保留不删，可以再运行一次。

## 常见问题

### 开机后壁纸不出来？

安装脚本已设置登录后 10 秒启动的计划任务。请在 Wallpaper Engine 设置里取消「高优先级」；原因、单独修复命令和撤销方法见 [壁纸自启踩坑记录](TROUBLESHOOTING.md)。

### Dock 突然不见了？

Nexus 有时开机后没跑起来，或被不小心关掉。配置还在，开始菜单搜索 **Nexus** 并打开，Dock 会原样回来。

### 隐藏桌面图标后找不到软件？

把它拖到 Dock，或从开始菜单固定到任务栏；也可以桌面右键 →「查看」→ 勾选「显示桌面图标」。

磁盘占用、性能与电池设置，以及上述问题的完整记录见 **[踩坑记录](TROUBLESHOOTING.md)**。

## 兼容性摘要

已测试环境：**Windows 11 家庭中文版、2560×1440、PowerShell 5.1**，覆盖安装、重复安装、还原、备份损坏时的报错；也测过非系统盘 Steam 库和已有同名壁纸自启任务的备份还原。

Windows 10、非中文系统、多显示器、高缩放比例和 PowerShell 7 **尚未验证**。

### 自动往返测试（GitHub 虚拟机）

每次 push 和 PR，`.github/workflows/roundtrip.yml` 会在 GitHub 的 `windows-latest` 虚拟机上用 Windows PowerShell 5.1 运行 `tests/test-roundtrip.ps1`，不占用任何人的电脑：

- **模拟环境**：不装付费软件。编译一个什么都不做的小程序，当作 Nexus 放到 `Program Files (x86)\Winstep\Nexus.exe`，当作 Wallpaper Engine 放到假的 Steam 库；用 `reg add` 造一份 3 个软件的 Dock 配置，准备 `config.json`、水墨壁纸的 `project.json`，以及一个指向记事本的同名计划任务 `WallpaperEngine_Logon`。
- **场景**：已有同名任务时 `install.ps1 -Yes -KeepMyApps -Style ink` → 重复安装（备份不得被覆盖）→ `restore.ps1`；没有同名任务时 `-ReplaceApps` → `restore.ps1`；两种损坏的 `backup\nexus-backup.reg`，还原必须返回非 0 且不改注册表。
- **判定**：检查退出码和结果表；还原后 Nexus、外观、任务栏注册表，计划任务 XML 和 `config.json` 与安装前逐项比较，必须 0 差异；Dock 软件的数量和路径不得变化，Nexus 和壁纸程序还原后仍在运行。

虚拟机上没有可靠的用户桌面 Explorer，所以测试设置了环境变量 **`RICE_DIRECT=1`**：`Start-Detached`、`Invoke-DesktopScript` 不再经 `explorer.exe` 转交，直接在当前进程执行。**这个开关只给测试用，不要在自己电脑上设置**，否则会失去绕开注册表隔离和进程回收的保护。没设置时脚本行为与以前相同。

虚拟机测不到的仍需真机验证：Wallpaper Engine 实际切换并渲染壁纸、Nexus 真实显示和外观、Explorer 转交与注册表隔离、截图。这个测试会改当前用户的桌面设置，脚本只允许在 GitHub Actions 里运行。详见 [兼容性表](COMPATIBILITY.md)；在其他环境用过，欢迎[提个 Issue](../../../issues/new/choose) 告诉我结果。

## 致谢与许可

感谢壁纸作者，以及 Wallpaper Engine 和 Winstep Nexus 的开发者。壁纸版权归各自作者所有，本仓库展示桌面实拍，并引用 Steam 创意工坊的链接和预览图；这两款软件属于各自开发者，本仓库与它们没有关联。

脚本和教程采用 [MIT 许可](../LICENSE)。版本变化见 [更新日志](../CHANGELOG.md)。
