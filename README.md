# Nintendo Switch 2 eShop：Mac + GOST 代理

在 Mac 上开放一个仅绑定家庭局域网地址的 HTTP 代理，再通过现有的 Clash Verge、Mihomo 或其他本机 SOCKS5/HTTP 节点转发 Switch 2 的 eShop 与游戏下载流量。

```text
Switch 2
  -> HTTP <Mac 局域网 IP>:<监听端口>
  -> GOST on macOS
  -> SOCKS5/HTTP 127.0.0.1:<本机代理端口>
  -> 现有香港/海外节点
  -> Nintendo eShop/CDN
```

项目不会解密 HTTPS、安装证书、缓存游戏文件或修改 Switch 系统。运行配置由每台 Mac 本地生成，仓库不包含固定 IP、节点、订阅或密码。

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/Miss-you/nintendo-acc.git
cd nintendo-acc
```

如果希望让编码 Agent 自动完成，请把 [PROMPT.md](PROMPT.md) 的内容交给它。Agent 在修改项目前应遵守 [AGENTS.md](AGENTS.md)。

### 2. 准备上游代理

打开 Clash Verge 或其他代理客户端，选择可用的香港/海外节点并确保代理核心正在运行。自动检测目前按顺序尝试：

- `socks5://127.0.0.1:7890`（常见 mixed-port）
- `socks5://127.0.0.1:7898`
- `http://127.0.0.1:7899`

不需要在 Clash Verge 中开启“允许局域网连接”；GOST 只连接它的回环端口。

### 3. 安装 GOST

```bash
brew install gost
```

项目使用 [go-gost/gost](https://github.com/go-gost/gost) v3 的 `-L` 和 `-F` 参数。

### 4. 自动生成本机配置

```bash
bin/nintendo-acc setup
```

该命令会检测默认网络接口、当前 RFC1918 局域网 IPv4 和可用的本机代理端口，然后生成不入库的 `config/nintendo-acc.env`。它最后会直接打印 Switch 应填写的服务器与端口。

如果默认端口不匹配，可以显式指定上游后重新生成：

```bash
NINTENDO_ACC_UPSTREAM_URL=socks5://127.0.0.1:1080 \
  bin/nintendo-acc setup --force
```

也可以覆盖自动探测结果：

```bash
NINTENDO_ACC_INTERFACE=en0 \
NINTENDO_ACC_LISTEN_HOST=<Mac局域网IP> \
NINTENDO_ACC_LISTEN_PORT=18080 \
NINTENDO_ACC_UPSTREAM_URL=http://127.0.0.1:8080 \
  bin/nintendo-acc setup --force
```

监听地址必须是 Mac 当前拥有的 RFC1918 私网 IPv4；上游必须是 `127.0.0.1`。脚本拒绝通配地址、回环监听、公网监听和远程上游。

### 5. 启动与验证

```bash
bin/nintendo-acc preflight
bin/nintendo-acc start
bin/nintendo-acc test
bin/nintendo-acc switch
```

预期结果：

- `preflight` 确认 GOST、Mac 地址、上游端口和监听端口可用。
- `start` 使用当前登录会话的 `launchctl` 托管服务。
- `test` 通过完整代理链访问任天堂 HTTPS 探测地址。
- `switch` 打印这台 Mac 的实际服务器地址和端口。

macOS 第一次询问是否允许 GOST 接受传入连接时，请核对程序后允许，否则 Switch 无法连接。

## Switch 2 配置

1. HOME →「系统设置」。
2. 「互联网」→「互联网设置」。
3. 选择当前已保存的 Wi-Fi →「更改设置」。
4. 找到「代理设置」，选择开启。
5. 按 `bin/nintendo-acc switch` 的输出填写：

   - 服务器：输出中的 Mac 局域网 IP
   - 端口：输出中的监听端口
   - 认证/自动认证：关闭

6. 保存，然后选择「连接到此网络」或运行「测试连接」。

任天堂官方路径参见 [How to Change/View Existing Internet Connection Settings](https://en-americas-support.nintendo.com/app/answers/detail/a_id/22316/~/how-to-change/view-existing-internet-connection-settings-on-nintendo)。

Switch 与 Mac 必须在同一局域网；访客 Wi-Fi、AP 隔离或客户端隔离会阻止它们互访。

## 休眠行为

`start` 实际提交的进程链是：

```text
launchctl -> /usr/bin/caffeinate -i -> gost
```

因此 GOST 运行期间允许显示器熄灭，但 `caffeinate -i` 会阻止空闲系统睡眠。真正进入睡眠后普通代理无法继续转发，所以：

- MacBook 下载期间建议接通电源并保持上盖打开。
- 合上 MacBook 上盖通常仍会强制睡眠；本项目不绕过 macOS 的合盖策略。
- 注销或重启后运行 `bin/nintendo-acc start` 重新启动当前登录会话的服务。
- `bin/nintendo-acc stop` 会停止代理，同时释放防睡眠断言。

## 常用命令

```bash
bin/nintendo-acc setup          # 首次检测并生成配置
bin/nintendo-acc setup --force  # 网络或端口变化后重新生成
bin/nintendo-acc preflight      # 启动前检查
bin/nintendo-acc start          # 启动代理并防止空闲睡眠
bin/nintendo-acc status         # 查看状态
bin/nintendo-acc test           # 验证 HTTPS 转发
bin/nintendo-acc switch         # 打印 Switch 参数
bin/nintendo-acc logs           # 最近 50 行日志
bin/nintendo-acc stop           # 停止并恢复正常睡眠行为
```

## 故障排查

### `setup` 找不到本地上游

先启动 Clash Verge/Mihomo 核心。若使用非标准端口，通过 `NINTENDO_ACC_UPSTREAM_URL` 显式指定；不要把订阅 URL 或节点密码写入仓库。

### Wi-Fi 切换后预检失败

Mac 的接口或 DHCP 地址可能变化。重新运行：

```bash
bin/nintendo-acc setup --force
```

然后按新的 `bin/nintendo-acc switch` 输出更新 Switch。长期使用可在路由器中为 Mac 设置 DHCP 地址保留。

### Switch 无法连接

- 确认 `bin/nintendo-acc status` 显示运行中。
- 确认 Mac 没有合盖睡眠。
- 确认 macOS 防火墙允许 GOST 入站。
- 确认 Switch 与 Mac 位于同一非隔离局域网。
- 查看 `bin/nintendo-acc logs`。

### 恢复 Switch 直连

```bash
bin/nintendo-acc stop
```

随后把 Switch 当前网络的代理设置关闭。只停止 Mac 代理而不关闭 Switch 设置，会导致 Switch 无法联网。

## 安全模型

- GOST 入口只允许绑定检测到的 RFC1918 地址，不允许 `0.0.0.0`、`::`、回环或公网地址。
- 上游默认只允许 `127.0.0.1`，避免把代理凭据暴露到局域网。
- `config/nintendo-acc.env`、`.runtime/` 和 `.worktrees/` 不提交。
- HTTP 入口默认无认证，同一局域网设备理论上可以使用；只在可信家庭网络运行，用完可停止。
- 如果上游 URL 含认证信息，它只保存在权限为 `600` 的本机配置中，日志输出会脱敏。

## 开发验证

```bash
bash -n bin/nintendo-acc lib/nintendo_acc.sh tests/nintendo-acc-test.sh
bash tests/nintendo-acc-test.sh
```

本项目是 eShop/游戏下载路径优化工具，不是透明路由器，也不保证加速未使用系统 HTTP 代理的 UDP 联机流量。最终速度仍取决于节点、跨境线路、任天堂 CDN、Wi-Fi 和存储性能。
