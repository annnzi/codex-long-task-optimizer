# codex-long-task-optimizer

一个用于提升 Codex 长任务可执行性的开源工具：把「需求-目标-约束-验收」提炼成可执行计划，生成可分批提交的长任务清单，并给出风险与回退建议。

## 目标
- 降低一次性超长任务导致的执行偏差
- 让每个中间产物可独立验证
- 方便在 GitHub Issue、PR、Codex 任务中复用固定模板

## 功能
- 解析任务文本中的关键区块（目标、范围、输出、约束、验收条件）
- 按 token 数（按字数近似）自动切分为若干子任务
- 生成三种输出：
  - 可直接复制到 Codex 的执行计划
  - 风险清单
  - 自动生成的回退点（每个阶段可回退）
- 可选输出 JSON，便于接入流水线

## 快速开始

```bash
cd codex-long-task-optimizer
python -m src.long_task_optimizer --input examples/sample-task.txt --max-tokens 140 --format md
```

### 参数
- `--input`：任务文本路径（默认 `examples/sample-task.txt`）
- `--max-tokens`：单步最大 token 粗估（默认 120）
- `--format`：输出格式，`md`（默认）或 `json`
- `--no-risk`：不生成风险章节

## 示例输出

```bash
python -m src.long_task_optimizer --input examples/sample-task.txt --format md
```

会输出类似：

1. 阶段 1：澄清边界与验收标准  
2. 阶段 2：搭建最小可验证模型  
3. 阶段 3：实现主流程  
4. 阶段 4：验证 + 回归 + 交付

每个阶段会带：
- 预估工作量
- 验收动作
- 回退计划
- 风险点

## 项目结构
- `src/long_task_optimizer.py`：核心 CLI
- `examples/`：任务示例与模板
- `CONTRIBUTING.md`：贡献指引
- `LICENSE`：MIT

## 贡献方式
1. Fork 本仓库
2. 新建分支（如 `feat/...`）
3. 修改后提交 PR
4. 使用清晰的任务描述（建议 1 页以内）

## 许可证
MIT，详见 [LICENSE](LICENSE)。
