<div align="center">

# 🌄 Win11 动态桌面 · 一键复刻

**动态壁纸 + macOS 风格 Dock + 隐身任务栏**
<br>
一个干净、会动的 Windows 11 桌面。装好两个软件，运行一个脚本，任务栏、桌面和 Dock 就会变成演示里的样子。

![Windows 11](https://img.shields.io/badge/Windows-11-0078D4?style=flat-square&logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?style=flat-square&logo=powershell&logoColor=white)
![一键还原](https://img.shields.io/badge/一键还原-支持-2ea44f?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)

<img src="docs/demo.gif" alt="桌面动态演示" width="100%">

<sub>☝️ 实录：云在飘，鼠标扫过 Dock 时图标放大</sub>

[一键安装](#-一键安装) · [壁纸画廊](wallpapers.md) · [Dock 配置](#-dock-配置) · [踩坑记录](#-踩坑记录) · [还原](#-一键还原) · [更新日志](CHANGELOG.md)

</div>

> [!IMPORTANT]
> **开始前请了解**
> - **脚本自动做的**：任务栏改深色并自动隐藏、隐藏桌面图标；替换 Nexus **第一个 Dock** 的外观和图标列表；设置 Wallpaper Engine 登录后自动启动。
> - **要你自己做的**：安装 Wallpaper Engine（付费）和 Nexus（免费），先打开一次 Nexus；订阅并选择壁纸；在 Wallpaper Engine 里取消「高优先级」。
> - **Dock 图标**：只检测 8 款常用软件的常见安装位置，装在别处的不会自动加上，可以手动拖上去。
> - **效果范围**：演示来自 Windows 11、2560×1440。分辨率、缩放比例和软件版本不同，效果可能略有差别。
> - **备份与还原**：改动前会自动备份到仓库里的 `backup\` 文件夹，`restore.ps1` 按备份还原。**还原前请不要删除这个文件夹。**

---

## ✨ 这个桌面有什么

| | |
| --- | --- |
| 🎬 **动态壁纸** | Wallpaper Engine 驱动，14 张精选壁纸：水墨、赛博朋克、动漫、风景 |
| 🧲 **底部 Dock** | Nexus Dock，鼠标划过图标会放大、有倒影、运行中的软件有指示点 |
| 🫥 **隐身任务栏** | 平时完全隐藏，鼠标移到屏幕最底部才出现 |
| 🧹 **零桌面图标** | 桌面上什么都不放，壁纸完整露出来 |
| ⚡ **开机稳定** | 修复了 Wallpaper Engine 开机不自动启动的老毛病 |
| ↩️ **随时还原** | 每一步都先备份，一个命令恢复成原来的样子 |

<details>
<summary>📷 查看高清静态截图</summary>

![桌面截图](docs/preview.jpg)

</details>

---

## 🚀 一键安装

### 第 0 步：装好两个软件

| 软件 | 价格 | 下载 |
| --- | --- | --- |
| **Wallpaper Engine** | Steam 付费，常年打折 | [Steam 商店](https://store.steampowered.com/app/431960/Wallpaper_Engine/) |
| **Winstep Nexus** | 免费 | [官网](https://www.winstep.net/nexus.htm) |

装完 Nexus 后**先打开一次**，等底部出现 Dock 再继续。

### 第 1 步：下载本仓库

点页面上方绿色的 **Code** → **Download ZIP**，解压到任意位置。

### 第 2 步：运行安装脚本

在解压出来的文件夹里，**按住 Shift + 右键空白处** →「在终端中打开」，粘贴下面这行，回车：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会先检查软件装了没有，问你一次确认，然后依次：

1. 把任务栏改成深色并自动隐藏，隐藏桌面图标
2. 导入我的 Dock 外观，在常见安装位置检测这几款软件，装了的放到 Dock 上：资源管理器、Edge、Chrome、QQ、微信、Steam、QQ 音乐、网易云音乐
3. 设置 Wallpaper Engine 登录后 10 秒自动启动。如果你原来就有同名的自启任务，会先完整备份

全程大约 10 秒，任务栏和 Dock 会闪一下。最后会列出每一步是「成功」「跳过」还是「失败」，某一步失败不会影响其他步骤。

### 第 3 步：挑一张壁纸

打开 **[壁纸画廊](wallpapers.md)**，点喜欢的那张，在 Steam 页面点「订阅」，然后在 Wallpaper Engine 里选中它。

<table>
<tr>
<td><a href="wallpapers.md#治愈--风景"><img src="https://images.steamusercontent.com/ugc/13404577843317080792/53DBF5327F133A4464F70C25F04E081E45B83C9C/" alt="Horizon Sky Wanderer"></a></td>
<td><a href="wallpapers.md#水墨--国风"><img src="https://images.steamusercontent.com/ugc/2174735808910714014/51E7DD1A3540B73D55075C99FF6218D50C0CA681/" alt="水墨侠客"></a></td>
<td><a href="wallpapers.md#赛博朋克"><img src="https://images.steamusercontent.com/ugc/1714157571901830497/748210052444E830D89F119F82D722A3647BDAE0/" alt="Cyberpunk Room"></a></td>
</tr>
<tr>
<td align="center"><sub>风景</sub></td>
<td align="center"><sub>水墨</sub></td>
<td align="center"><sub>赛博朋克</sub></td>
</tr>
</table>

---

## 🧲 Dock 配置

`install.ps1` 会自动导入下面这些设置（存在 [`config/nexus-dock.json`](config/nexus-dock.json)）。想手动调，右键 Dock → **Preferences**。

| 设置 | 我的值 | 效果 |
| --- | --- | --- |
| 主题 | Windows10Nx（Nexus 自带） | 半透明圆角底板 |
| 图标大小 | 40 px | 平时小巧不挡壁纸 |
| 放大到 | 128 px | 鼠标划过时的放大尺寸 |
| 放大范围 | 3 | 鼠标附近几个图标一起放大，过渡更顺 |
| 倒影 | 128 | 图标下方的镜面倒影 |
| 图标间距 | 8 px | |
| 运行指示 | 开 | 正在运行的软件下面有小点 |
| 位置 | 屏幕底部居中 | |

> 你也可以分享你自己的 Dock：调好后运行 `scripts\export-nexus.ps1`，它只导出外观，不会带上你的软件路径、天气城市等个人信息。

---

## 🕳️ 踩坑记录

这些都是我自己真实遇到过的问题。

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

---

## ↩️ 一键还原

不喜欢？一个命令把脚本做的改动恢复回去：

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

它会按 `backup\` 文件夹里的备份逐项恢复：

- 任务栏和桌面的 5 项设置恢复成原来的值
- Nexus 的配置整块恢复；恢复前会先另存当前配置，万一失败会自动退回
- Wallpaper Engine 自启任务：原来就有的恢复原设置，原来没有的删掉

某一步没还原成功，会显示「失败」，对应的备份保留不删，可以再运行一次。

---

## 📁 文件说明

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
└── docs/                             演示动图和截图
```

## 💻 兼容性

| 环境 | 状态 |
| --- | --- |
| Windows 11 家庭中文版，2560×1440，PowerShell 5.1 | ✅ 已测试：安装、重复安装、还原、备份损坏时的报错 |
| Wallpaper Engine 装在非系统盘的 Steam 库 | ✅ 已测试 |
| 原来已有 `WallpaperEngine_Logon` 计划任务 | ✅ 已测试：安装前备份，还原后与原任务完全一致 |
| Windows 10 | ❓ 未验证 |
| 英文等非中文系统 | ❓ 未验证 |
| 多显示器、高缩放比例 | ❓ 未验证 |
| PowerShell 7 | ❓ 未验证 |

在其他环境用过？欢迎[提个 Issue](../../issues/new/choose) 告诉我结果。

所有脚本都只改**当前用户**的设置，**不需要管理员权限**，也请不要用「以管理员身份运行」：如果你平时用的不是管理员账户，用别的账户提权运行会改到那个账户的设置。

## 📄 许可

脚本和教程采用 [MIT 许可](LICENSE)。壁纸版权归各自作者所有，本仓库只引用 Steam 创意工坊的链接和预览图。Wallpaper Engine 和 Winstep Nexus 是各自开发者的软件，本仓库与它们没有关联。
