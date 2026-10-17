# re-harness

逆向分析工具链的 **CI 执行台**：把 Ghidra headless 那套跑在 GitHub Actions 上，
省掉本机内存（本地沙箱只有 3.8 G，gateway 就吃掉 1.9 G）。

## 定位

本仓库是**逆向工具链本体**（workflow + 脚本 + Ghidra 脚本），
属于 GitHub Actions 允许的用途：与仓库关联软件的构建 / 测试 / 运行。

**产物一律不进本仓库**（本仓库 public，日志与 artifact 人人可见）：
分析结果由 workflow 推送到私有仓库 `re-results`。

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
| `push_results` | 结果推到私有库 `re-results`（默认开） |
| `upload_artifact` | 在公开仓库留 artifact（默认关，**开了等于公开产物**） |

## 结果去哪

`re-results` 私有库，每次运行一个目录：

```
<run_number>-<binary_name>/
├── summary.txt        # 架构 / 编译器 / 函数数 / 符号数 / sha256
├── decompiled.c       # 反编译伪代码（截断到 max_functions）
├── strings.txt        # 字符串抽取
├── analyze.log        # Ghidra 完整日志
└── meta.json          # run URL、输入参数、runner 规格
```

## 安全

- `RE_PUSH_TOKEN`：repo 范围 PAT，只用于推 `re-results`。公开仓库的 secret 只注入
  `workflow_dispatch`（本 workflow 无 `pull_request` 触发），且仓库已开
  "Require approval for all outside collaborators"。
- **不要往公开仓库 echo 任何 token**；workflow 里只走 env。
- 目标物合法性自负：只分析自有 / 开源 / 已授权样本。
- 只推分析产物，**不推原始二进制**。
