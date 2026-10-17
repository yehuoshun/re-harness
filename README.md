# re-harness

逆向分析工具链的 **CI 执行台**：把 Ghidra headless 跑在 GitHub Actions 上，
省掉本机内存（本地沙箱只有 3.8 G，gateway 就吃掉 1.9 G）。

## 定位

本仓库是**逆向工具链本体**（workflow + 脚本 + Ghidra 脚本），
属于 GitHub Actions 允许的用途：与仓库关联软件的构建 / 测试 / 运行。

**明文产物绝不进本仓库**（本仓库 public）。流程：CI 打包 → AES 加密 →
公开 artifact（只有密文）→ 沙箱解密 → 归档进语雀。

## 能力边界

| 能 | 不能 |
|---|---|
| Ghidra headless 反编译（ELF / PE / Mach-O） | IDA Pro（授权 + GUI） |
| 批量 / matrix 并行分析 | 交互式一轮轮试（冷启动 1-2 分钟） |
| ARM64 原生分析（`ubuntu-24.04-arm`） | 硬件 / 内核 / 动态调试 |
| 函数清单 + 伪代码 + 符号/字符串汇总 | 超大固件（标准 runner 7-16 G 内存、14 G 盘） |

## 用法

Actions → `ghidra-headless` → Run workflow：

| 输入 | 说明 |
|---|---|
| `mode` | `smoke` = 现场编译一个测试二进制验证管线；`analyze` = 下载 `binary_url` 分析 |
| `binary_url` | `analyze` 模式必填，直链（海外源建议带 `https://gh-proxy.com/` 前缀） |
| `binary_name` | 保存文件名，如 `target.dll` |
| `ghidra_version` | 默认 `12.1.4`（与本地沙箱一致） |
| `max_functions` | 最多反编译多少函数，`0` = 全部（慎用，大二进制会超时） |
| `maxmem` | JVM 堆上限，默认 `4g`（**必须封顶**，Ghidra 默认按物理内存贪） |

## 产物通道

```
CI（公开仓，免费 16G）
  out/{summary.txt, decompiled.c, strings.txt, analyze.log, meta.json}
    └─ scripts/bundle.py pack → tar.gz → AES-256-CBC + PBKDF2(200k)
         └─ 公开 artifact: re-bundle-<N>.enc（只有密文，留 3 天）
              └─ 沙箱 scripts/re-harness-sync.sh 拉取 + 解密（RE_BUNDLE_PASS）
                   └─ 语雀知识库（多端同步浏览）→ 随后删除 GitHub artifact
```

- 打包/解包是**同一个文件**（`scripts/bundle.py`），避免两套实现对不上。
- `RE_BUNDLE_PASS`：32 字节随机密码，存沙箱 `credentials.env` + 本仓 secret。
- 目标二进制**永不入库、永不上传**，job 结束前在 runner 上删除。

## 使用约束（2026-10-18 拍板）

- **按需手动触发**（`workflow_dispatch`），一次一个目标，**不做长任务**。
- 不加 `schedule`、不做批量 matrix、不堆并行——本仓定位是「单次分析执行台」，不是算力农场。
- 单次任务 `timeout-minutes: 90` 封顶，超时即终止。
- 目标物以**自有 / 开源 / 已授权**为主；闭源标的走私有仓 + 计费分钟，或不用 GitHub。

## 安全

- 本仓只依赖 `RE_BUNDLE_PASS`（对称密码）+ 加密 artifact，**不放账号级 API token**。
- 语雀写入由沙箱侧 MCP 完成（不在 CI 里直连语雀 API）。
- 公开仓 secret 只注入 `workflow_dispatch`（本 workflow 无 `pull_request` 触发）。
- **不要在任何 workflow 里 echo token/密码**。
- 目标物合法性自负：只分析自有 / 开源 / 已授权样本。
