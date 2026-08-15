# AGENTS.md

本文件适用于整个仓库。任何 Agent 修改、部署或发布本项目时都必须遵守。

## 项目目标

本项目在 macOS 上运行一个面向同一可信局域网的 GOST HTTP 入口，并把流量链到 Mac 本机回环地址上的 SOCKS5/HTTP 代理，供 Nintendo Switch 2 的 eShop 和游戏下载使用。

它不是透明路由器、TLS 中间人、游戏下载缓存或完整 UDP 联机加速器。

## 不可破坏的安全约束

- 运行配置不得硬编码任何开发者或历史机器的 IP；使用 `bin/nintendo-acc setup` 在目标 Mac 生成。
- GOST 入口只能绑定目标 Mac 当前拥有的 RFC1918 IPv4。
- 必须拒绝 `0.0.0.0`、`::`、回环监听和公网监听。
- 上游代理默认只能指向 `127.0.0.1`，不得自动连接局域网或公网代理。
- 不要读取、打印、提交或上传订阅 URL、节点密码、API token、Cookie、私钥或完整 Clash/Mihomo 配置。
- `config/nintendo-acc.env`、`.runtime/` 和 `.worktrees/` 必须保持在 `.gitignore` 中。
- 日志和用户输出中的上游认证信息必须脱敏。
- 不得通过关闭 macOS 安全功能、绕过防火墙或创建特权系统守护进程来“修复”连接。

## 权限和用户确认

只读探测可以直接执行。以下动作发生前必须向用户说明影响并取得确认：

- 使用 Homebrew 安装软件。
- 启动面向局域网的监听器。
- 修改系统代理、防火墙、VPN、网络接口或电源设置。
- 创建 GitHub 仓库、改变可见性或推送内容。

不要替用户选择、购买或切换付费代理节点。GUI 中出现密码、订阅或节点详情时，不得复制到输出。

## 实现规范

- 兼容 macOS 自带 Bash 3.2；不要依赖 Bash 4 的关联数组、`mapfile` 等功能。
- 使用 Bash 数组传递 GOST/launchctl 参数；不得用 `eval` 拼接命令。
- 默认接口来自 `route -n get default`，IPv4 来自 `ipconfig getifaddr`；探测失败时明确报错，不要退回写死 `en0` 或固定 IP。
- 生成 `config/nintendo-acc.env` 时先验证，再原子替换，并设置权限 `600`。
- 已存在本地配置时不得静默覆盖；要求用户显式使用 `setup --force`。
- 服务使用当前登录会话的 `launchctl` 管理，并保持 `/usr/bin/caffeinate -i` 包裹 GOST。
- `stop` 必须同时停止代理并释放防睡眠断言。
- MacBook 合盖睡眠不是本项目要绕过的行为。
- 保持依赖最小：GOST 是唯一需要通过 Homebrew 安装的运行依赖。

## 文件职责

- `bin/nintendo-acc`：CLI、配置生成、预检和生命周期管理。
- `lib/nintendo_acc.sh`：纯校验、检测、渲染和参数构建函数。
- `config/nintendo-acc.env.example`：不含机器数据的配置字段说明。
- `config/nintendo-acc.env`：目标机器本地生成，永不提交。
- `tests/nintendo-acc-test.sh`：离线行为和文档契约测试。
- `README.md`：给使用者的完整说明。
- `PROMPT.md`：给目标机器 Agent 的部署任务。
- `docs/plans/`：设计与实施决策。

## 开发流程

行为变更必须遵守 TDD：先写测试并观察目标失败，再写最小实现，最后重新运行全套测试。文档中的关键安装和安全约束也应有契约测试。

每次宣告完成前执行：

```bash
bash -n bin/nintendo-acc lib/nintendo_acc.sh tests/nintendo-acc-test.sh
bash tests/nintendo-acc-test.sh
```

提交前还必须：

- 运行 `git diff --check`。
- 确认 `git status --short` 中没有本机配置、日志或运行目录。
- 扫描 API key、Bearer token、密码 URL、私钥、订阅 URL 和异常长的 `.env` 值。
- 检查文档和示例没有真实机器 IP、用户名、绝对用户路径或凭据。

## 部署验收

目标 Mac 的完成标准：

1. `bin/nintendo-acc setup` 生成合法且被忽略的本地配置。
2. `bin/nintendo-acc preflight` 通过。
3. `bin/nintendo-acc start` 后 `status` 显示运行中。
4. `bin/nintendo-acc test` 经代理访问 HTTPS 成功。
5. `bin/nintendo-acc switch` 输出 Switch 应填写的实际地址和端口。
6. 用户已知晓同一局域网、macOS 防火墙、MacBook 合盖、重启重启服务以及停止后关闭 Switch 代理的要求。

没有实时命令证据时，不得声称部署、测试或发布成功。
