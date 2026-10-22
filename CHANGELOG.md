# 更新日志

## 未发布

- 新增 GitHub Actions 往返测试 `roundtrip.yml` 和 `tests/test-roundtrip.ps1`：在 `windows-latest` 虚拟机上模拟 Nexus、Wallpaper Engine 和已有同名计划任务，跑「安装 → 重复安装 → 还原」（`-KeepMyApps -Style ink` 与 `-ReplaceApps` 两种）和备份损坏的失败路径，还原后要求与安装前 0 差异。说明见 [指南](docs/GUIDE.md#自动往返测试github-虚拟机)。
- 新增仅供测试的环境变量 `RICE_DIRECT=1`：`Start-Detached`、`Invoke-DesktopScript` 不经 Explorer 转交，直接执行；未设置时行为不变。
- 修复还原后桌面图标仍然隐藏（往返测试发现）：资源管理器启动时会按桌面视图 `Shell\Bags\1\Desktop\FFlags` 的「不显示图标」位改写 `HideIcons`，只还原 `HideIcons` 会被改回去；`apply-look.ps1 -Undo` 现在把这一位一起设回原样，旧备份同样适用。
- 重启资源管理器只处理当前会话；当前会话没有资源管理器时跳过重启，不再报错退出（原来 `Stop-Process` 找不到进程会让外观步骤失败）。

## v1.2.1 · 2026-10-22

修复 AI 助手运行脚本时的两个问题：装完后壁纸和 Dock 被一起关掉；在打包的桌面 AI 应用里注册表改动只写进隔离区、真实桌面不生效。

- 外观应用与 `-Undo` 通过 `Invoke-DesktopScript` 将备份、HKCU 写入、重启 Explorer 和恢复 TranslucentTB 的完整事务交给桌面工作进程；隐藏的 `-DesktopSession` 开关防止循环转交。
- 共享 Nexus 外观配置与导出过滤名单排除 `DockNoItems1`（作者电脑的最后图标序号），避免导入后丢图标或出现空位；保留 `KeepMyApps` 的防御性跳过逻辑。
- AI 安装说明补充 HKCU 隔离和 Explorer 视图验证要求；新增 `tests/test-desktop-launch.ps1` 回归检查。
- Nexus、Wallpaper Engine、TranslucentTB 统一经资源管理器启动，命令结束后不会被一起关掉；还原后不再残留 `wallpaper-config-before-undo.json`。
- 重拍全部截图和动图：Dock 左侧不再有 NeXuS 标志。
- 真机验证（以资源管理器看到的真实注册表为准）：`install.ps1 -Yes -KeepMyApps -Style ink` 后换一条命令检查，三个程序仍在运行、壁纸为水墨；`restore.ps1` 后 Dock、外观、计划任务、壁纸与安装前逐项对比 0 差异。

## v1.2.0 · 2026-10-22

- 安装新增 `-Yes`、互斥的 `-KeepMyApps` / `-ReplaceApps`、`-Style`；无参数保留交互流程，不提问模式默认保留现有软件。
- 新增 `scripts/prepare.ps1`：只读准备检查、显式 winget 安装 Nexus、首次运行等待和结果表；不自动购买 Wallpaper Engine。
- 新增 `scripts/set-style.ps1`：风景、水墨、赛博朋克映射，Steam 订阅提示、下载轮询和 `-NoWait`；命令执行前备份完整配置及原壁纸路径清单。
- `restore.ps1` 增加壁纸配置恢复；首次备份不覆盖，SHA256 校验，恢复前保留当前配置。
- 高优先级未找到可确认的配置字段，保留手动关闭提示，不修改服务。
- 新增 AI 安装说明 `AGENTS.md`、`CLAUDE.md`，首页增加复制即用提示，指南补充参数、退出码与验证边界。
- Dock 配置加入 `DockHideControlIcon1=True`，安装时隐藏左侧 NeXuS 标志。
- 重启资源管理器时，自动恢复原来在运行的 TranslucentTB（之前会被一起关掉，任务栏不再透明）。
- 真机验证：让一个全新的 AI 只凭一句话「按 AGENTS.md 安装，风格选水墨」完成了准备检查 → 安装 → 切换水墨壁纸；随后 `restore.ps1` 还原，桌面状态与安装前逐项对比 0 差异，TranslucentTB 全程保持运行。

## v1.1.0 · 2026-10-22

### 桌面打磨
- Dock 图标统一：从软件里提取 256×256 原图标，去掉留白、统一视觉大小（圆形图标略放大），方形和圆形混排也整齐
- 新增 `-KeepMyApps`：保留你 Dock 上现有的软件，只统一图标；安装时会询问
- Dock 图标从 40 px 调到 48 px，间距从 8 px 调到 12 px
- 图标不随仓库分发（品牌图标版权归各公司），安装时从你自己电脑上的软件提取

### 演示
- README 开头改成静态主图，打开就能看到，不用等动图加载
- 新的 60 帧动态演示（WebP）：全景 → 划过 Dock → 呼出任务栏，替换原来 12 帧、7.7 MB 的 GIF
- 新增 Dock 放大效果特写

## v1.0.0 · 2026-10-22

第一个正式版本。

### 新增
- `install.ps1` / `restore.ps1`：一键安装和一键还原，最后列出每一步「成功 / 跳过 / 失败」
- Nexus Dock 配置导入导出（`apply-nexus.ps1` / `export-nexus.ps1`），自动检测 8 款常用软件放上 Dock
- 壁纸画廊：14 张创意工坊壁纸，带预览图和订阅数
- 桌面动态演示 GIF、踩坑记录、兼容性表格
- Issue 模板：问题反馈、兼容性报告
- GitHub Actions：语法检查、BOM 检查、PSScriptAnalyzer

### 可靠性
- 已有 `WallpaperEngine_Logon` 计划任务时，安装前完整备份，还原时恢复原设置（之前会直接覆盖）
- 子脚本失败时，安装和还原会显示「失败」并返回错误码（之前仍显示完成）
- Nexus 还原只处理 Nexus 自己的配置；恢复前先另存当前配置，导入失败自动退回
- 不再写死 Nexus 安装路径：先找运行中的进程，再查安装信息
- Dock 主题路径按目标电脑的公共文档目录转换，主题不存在时跳过主题设置
- 重复运行安装不会覆盖第一次的备份
- 还原时删除安装过程中新建的空注册表项
- 导出 Nexus 配置时，按个人文件夹路径而不是用户名判断隐私
- 硬盘扫描：每个 Steam 库单独列出
