# 踩坑记录

[← 返回 README](../README.md)

这些都是我自己真实遇到过的问题。文中的命令均在仓库根目录运行。

<details>
<summary><b>助手命令结束后 Dock / 壁纸消失，或隐藏 NeXuS 标志不生效</b></summary>

常驻程序现在统一通过 `explorer.exe "程序路径"` 启动，并检查当前会话、安装目录内的进程是否出现；壁纸控制命令仍独立等待退出并检查退出码。

本机还复现了另一种情况：受控终端与 Explorer 启动的普通 PowerShell 读到的 HKCU 配置不同。终端里的 `DockHideControlIcon1="True"` 不能证明桌面上的 Nexus 正在使用这份配置。正确字段仍是该字符串值，无需删除软件或换成别的注册表类型。

`apply-nexus.ps1` 现在把备份、修改、还原整个事务交给 Explorer 启动的普通用户工作进程，回传日志和退出码。每次改动前另存带时间戳的完整 WinSTEP 注册表；`-KeepMyApps` 同时保留真实桌面的软件列表和数量。等待超时会保留工作目录并提示不要重复运行，先检查日志。

这项修复已在本机进行显示／隐藏对照、冷启动、导入和还原检查；仍需在其他环境核对实际画面。已有旧备份可能来自另一注册表视图，请勿仅凭字段相同就导入。

可运行无桌面改动的回归检查：`powershell -ExecutionPolicy Bypass -File .\tests\test-desktop-launch.ps1`。

</details>

<details>
<summary><b>开机后壁纸不出来，桌面是黑的/默认壁纸</b></summary>

<br>

**原因**：Wallpaper Engine 设置里勾了「高优先级」后，它改成靠一个后台服务开机启动。我之前用优化软件关过自启项，那个服务被改成了「手动」，开机时就没人去启动它。

**解决**：`install.ps1` 已经帮你处理了（建一个登录后 10 秒启动的计划任务）。单独修复可以运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\fix-wallpaper-autostart.ps1
```

撤销这个修复，把 `.ps1` 后面加上 ` -Undo` 再运行一次就行。

然后在 Wallpaper Engine 设置里**取消勾选「高优先级」**，否则它会切回依赖后台服务的模式。

</details>

<details>
<summary><b>Dock 突然不见了</b></summary>

<br>

Nexus 的开机自启是开着的，但有时开机后它没跑起来（或者被不小心关掉了）。配置都还在，重新打开就行：开始菜单搜索 **Nexus** 打开，Dock 会原样回来。

</details>

<details>
<summary><b>隐藏桌面图标后，找不到游戏/软件了</b></summary>

<br>

我装了一个游戏模组，美化后桌面图标全藏起来，一时找不到入口。三个办法：

- 把它拖到 Dock 上（最方便）
- 开始菜单里找到它，右键 →「固定到任务栏」
- 临时显示桌面图标：桌面右键 →「查看」→ 勾选「显示桌面图标」

</details>

<details>
<summary><b>C 盘/D 盘越来越满</b></summary>

<br>

创意工坊壁纸订阅多了很占地方，我的 14 张就有 3.2 GB。不用的壁纸在 Wallpaper Engine 里右键 →「取消订阅」就会删掉。

想看看还有什么占空间，运行扫描脚本（**只看不删**）：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\scan-disk.ps1
```

</details>

<details>
<summary><b>动态壁纸会不会卡、费电？</b></summary>

<br>

视频类壁纸占用很低。建议在 Wallpaper Engine 设置 →「性能」里：

- 其他应用全屏时：**暂停**（打游戏不占显卡）
- 使用电池时：**暂停**（笔记本省电）

</details>

## 文件说明

```
├── install.ps1                       一键安装
├── restore.ps1                       一键还原
├── wallpapers.md                     壁纸画廊（14 张，带预览图）
├── config/
│   └── nexus-dock.json               我的 Dock 外观配置
├── CHANGELOG.md                      更新日志
├── scripts/
│   ├── common.ps1                    公共检测函数（Steam、Wallpaper Engine、Nexus 的位置）
│   ├── apply-look.ps1                任务栏和桌面设置
│   ├── apply-nexus.ps1               导入 Dock 配置
│   ├── export-nexus.ps1              导出你自己的 Dock 配置
│   ├── fix-wallpaper-autostart.ps1   修复壁纸开机自启
│   └── scan-disk.ps1                 扫描硬盘占用（只看不删）
└── docs/                             使用文档、演示动图和截图
```
