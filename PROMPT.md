# 目标 Mac 自动部署 Prompt

把下面整段内容复制给目标 Mac 上有终端与本地文件访问能力的编码 Agent。不要预先替换任何 IP；目标 Agent 必须在那台机器上检测。

---

请在这台 Mac 上部署 Nintendo Switch 2 eShop 的 GOST 代理。目标是让同一家庭局域网中的 Switch 2 使用 Mac 的 HTTP 入口，再链到这台 Mac 已有的 Clash Verge、Mihomo、SOCKS5 或 HTTP 本地代理。

执行要求：

1. 如果仓库不存在，运行：

   ```bash
   git clone https://github.com/Miss-you/nintendo-acc.git
   cd nintendo-acc
   ```

   如果已经存在，进入仓库并先检查工作区，保留用户已有改动。

2. 完整阅读 `AGENTS.md` 和 `README.md` 后再行动，并按其中的测试、安全和权限规则执行。

3. 不得硬编码本 Prompt、README、其他机器或历史记录里的局域网 IP。必须在目标 Mac 上检测默认网络接口和当前 RFC1918 IPv4。不得监听 `0.0.0.0`、`::`、回环或公网地址。

4. 只读取识别本机代理监听端口所需的信息。不要读取、展示或提交 Clash/Mihomo 的订阅 URL、节点密码、访问令牌或完整代理配置。

5. 先做只读检查：

   - 确认操作系统是 macOS。
   - 检查 Homebrew、GOST、`route`、`ipconfig`、`nc`、`lsof`、`launchctl`、`caffeinate` 和 `curl`。
   - 检查本机 Clash/Mihomo 核心是否已经监听回环代理端口。
   - 不要替用户切换代理节点。

6. 在安装软件、启动局域网监听器、修改系统代理/防火墙/网络设置之前，请在动作发生前说明影响并请求用户确认。若只需用户在 Clash Verge 中启动现有核心，应给出明确步骤；不要擅自读取节点详情。

7. 如果缺少 GOST，在用户确认后使用官方 Homebrew formula 安装：

   ```bash
   brew install gost
   ```

8. 让现有本地代理核心处于运行状态，然后执行：

   ```bash
   bin/nintendo-acc setup
   ```

   `setup` 会生成被 Git 忽略的 `config/nintendo-acc.env`。如果标准端口检测失败，先通过只读端口检查确定实际回环端口，再使用 `NINTENDO_ACC_UPSTREAM_URL` 显式指定并运行 `setup --force`。上游必须是 `127.0.0.1`。

9. 检查生成的配置：监听地址必须是目标 Mac 当前拥有的 RFC1918 地址，监听端口未占用，上游只能是回环地址。不得把本机配置加入 Git。

10. 在用户确认启动局域网监听后运行：

    ```bash
    bin/nintendo-acc preflight
    bin/nintendo-acc start
    bin/nintendo-acc test
    bin/nintendo-acc switch
    ```

11. 验证以下结果后才能宣告完成：

    - Bash 语法检查通过。
    - `bash tests/nintendo-acc-test.sh` 全部通过。
    - `preflight` 通过。
    - `status` 显示由 `launchctl` 管理的进程正在运行。
    - `test` 经完整代理链访问任天堂 HTTPS 成功。
    - 启动参数包含 `/usr/bin/caffeinate -i`，使显示器可关闭但阻止空闲系统睡眠。

12. 最终用中文向用户报告：

    - 实际检测到的 Mac 局域网 IP、GOST 端口和脱敏后的上游 URL。
    - Switch 路径：HOME → 系统设置 → 互联网 → 互联网设置 → 当前网络 → 更改设置 → 代理设置。
    - Switch 的服务器、端口以及“认证/自动认证关闭”。
    - MacBook 需要保持上盖打开；真正睡眠时代理无法工作。
    - 注销/重启后需重新运行 `bin/nintendo-acc start`。
    - 停止命令是 `bin/nintendo-acc stop`，停止后还要关闭 Switch 的代理设置。

遇到不确定的网络接口、多个可用上游或权限提示时停止猜测，提供已取得的只读证据并向用户确认。不要创建公网监听，不要上传本机配置，不要提交或推送用户的任何凭据。

---
