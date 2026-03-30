# Robot Self-Evolution (RSE)

面向机器人长程任务的自进化框架（仿真优先）。

## 目标
把复杂任务拆成子任务并执行；在线判定 `running/success/fail`；统计高频失败子任务；自动触发资产生成与 RL 训练；训练后回灌策略版本，形成闭环。

## 当前范围（MVP）
- 任务编排与子任务接口契约
- 判定器（状态 + 超时 + 无进展）
- 失败统计与训练触发
- 示例任务链：导航拿苹果放盘子再返回

## 快速开始
```bash
cd robot-self-evolution
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
python scripts/run_demo.py
```

## 目录
- `docs/interface-spec-v1.md`：接口规范
- `docs/project-architecture.md`：架构说明
- `docs/rl-module-integration.md`：RL 合作模块接入说明
- `docs/collaborator-integration-playbook.md`：合作者快速集成手册（含仿真环境对接）
- `docs/http-grpc-placeholder-guide.md`：HTTP/gRPC 占位实现说明
- `docs/llm-integration-qwen-vl.md`：大模型接入说明（Qwen-VL）
- `src/rse/core/`：核心数据结构和协议
- `src/rse/loop/`：执行、判定、统计、触发逻辑
- `src/rse/adapters/`：导航工具/VLA/训练器的适配层（占位）
- `configs/demo.yaml`：示例配置
- `scripts/run_demo.py`：最小闭环演示

## 下一步
1. 接入真实导航 tool adapter
2. 接入 VLA manipulation adapter
3. 将事件日志写入数据库（Parquet/SQLite）
4. 把训练触发接到你们云端 RL 管线
5. 接入 LLM planner/judge（可配 Qwen-VL）
