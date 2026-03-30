# 项目架构说明（v1）

## 核心模块

1. **Task Execution Layer**
   - 负责按任务链执行子任务（导航/VLA 操作）
2. **Judge Layer**
   - 实时判定 `running/success/fail`
   - 内含超时与无进展规则
3. **Failure Mining Layer**
   - 聚合失败率与 failure code 分布
4. **Evolution Trigger Layer**
   - 依据门槛触发训练
5. **RL Adapter Layer**
   - 与云端训练系统解耦对接

## 关键设计原则

- **接口先行**：先定义契约，再集成模型/工具
- **可观测优先**：没有日志就没有进化
- **单失败点闭环**：先把一个子任务从失败拉起来，再扩展
- **版本化回灌**：训练结果必须带策略版本，允许回滚

## 数据流

`SubTask Execution -> Judge -> FailureStats -> TrainingTrigger -> RLTrainerAdapter -> TrainResult -> Policy Registry`

## 当前仓库映射

- `docs/interface-spec-v1.md`：子任务契约
- `src/rse/core/models.py`：统一模型
- `src/rse/loop/judge.py`：判定逻辑
- `src/rse/loop/stats.py`：统计逻辑
- `src/rse/loop/trigger.py`：触发逻辑
- `src/rse/loop/evolution.py`：训练编排
- `src/rse/adapters/rl_contracts.py`：RL 请求/结果契约
- `src/rse/adapters/rl_trainer.py`：RL 适配抽象接口 + mock 实现
