# LLM 集成说明（Qwen-VL）

你现在可以在本项目里把任务拆解器和状态判断器接到大模型。

## 1) 已新增模块

- `src/rse/adapters/llm_client.py`
  - OpenAI-compatible client（可对接 Qwen-VL 兼容接口）
- `src/rse/adapters/llm_planner.py`
  - `LLMTaskPlanner`：高层任务 -> 子任务链
- `src/rse/adapters/llm_judge.py`
  - `LLMTaskJudge`：观测/遥测 -> 状态判定
- `configs/llm.example.yaml`
  - LLM 配置模板

## 2) 你要在哪里配置大模型

两种方式都支持（推荐环境变量）：

### 方式 A（推荐）环境变量
```bash
export RSE_LLM_BASE_URL="https://dashscope.aliyuncs.com/compatible-mode/v1"
export RSE_LLM_API_KEY="<你的key>"
export RSE_LLM_MODEL="qwen-vl-max"
export RSE_LLM_TIMEOUT_S="30"
```

### 方式 B（文件模板）
编辑：`configs/llm.example.yaml`
- `llm.base_url`
- `llm.model`
- `llm.timeout_s`
- `llm.api_key_env`（指向你存 API key 的环境变量名）

## 3) Qwen-VL 典型配置

- base_url（兼容模式）：`https://dashscope.aliyuncs.com/compatible-mode/v1`
- model：`qwen-vl-max`（你也可以替换成你要的 Qwen-VL 型号）
- API key：走环境变量，不写进 git

## 4) 如何运行最小验证

```bash
cd robot-self-evolution
source .venv/bin/activate
PYTHONPATH=src python scripts/llm_smoke_test.py
```

如果环境变量没配置，会直接报缺少变量；配置正确则会打印 planner/judge 结果。

## 5) 工程建议（必须）

- LLM judge 只做“软判定”，规则判定（timeout/no_progress）保留为硬约束
- 增加 `min_confidence` 门槛，低置信度走 rule-based fallback
- 落日志：prompt摘要、模型名、判定结果、最终采纳来源
- 不要把 API key 写进代码或配置仓库
