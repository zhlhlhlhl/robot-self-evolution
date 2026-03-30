# RL 模块化集成说明（给合作者）

本文档定义 RL 训练侧和主系统（RSE）之间的标准接口，目标是：
- 解耦：主系统不关心 RL 内部实现
- 可替换：本地 mock、云端训练器可随时替换
- 可追溯：每次训练都有 request_id/job_id/版本号

---

## 1. 代码入口

- 抽象接口：`src/rse/adapters/rl_trainer.py::RLTrainerAdapter`
- 请求/结果契约：`src/rse/adapters/rl_contracts.py`
- 触发编排：`src/rse/loop/evolution.py::EvolutionOrchestrator`

你们 RL 团队只需要：
1) 新建一个类继承 `RLTrainerAdapter`
2) 实现 `submit`、`status`、`fetch_result`
3) 在主流程中注入该实现

---

## 2. 接口定义

### 2.1 submit(req: TrainRequest) -> job_id
输入：
- `task_id`: 需要提升能力的子任务（如 `pick_apple`）
- `dominant_failures`: 主要失败模式（如 `grasp_slip`, `ik_failed`）
- `scenario`: 训练场景约束（对象集合、随机化参数、任务条件）
- `reward`: reward 版本和项
- `policy_version_before`: 训练前策略版本

输出：
- `job_id`: 云端训练任务唯一 ID

### 2.2 status(job_id) -> TrainingJobStatus
统一状态：
- `queued`
- `running`
- `succeeded`
- `failed`
- `canceled`

### 2.3 fetch_result(job_id) -> TrainResult
必填结果字段：
- `request_id`
- `job_id`
- `status`
- `policy_version_after`（成功时）
- `metrics`（至少包含 success_rate 相关指标）
- `artifacts`（checkpoint/log URL）
- `error`（失败时）

---

## 3. 推荐最小指标（metrics）

建议 RL 侧统一回传：
- `eval_success_rate_before`
- `eval_success_rate_after`
- `success_rate_delta`
- `episodes`
- `train_wall_time_hours`
- `safety_violation_rate`

这样主系统可以自动做 before/after 对比与回灌验收。

---

## 4. 训练触发与回灌时序

1) 主系统统计失败频率（`FailureStats`）
2) 触发器判定是否满足训练条件（`TrainingTrigger`）
3) 编排器构建 `TrainRequest` 并提交训练
4) RL 侧返回 `TrainResult`
5) 主系统依据 `policy_version_after` 更新策略版本映射

建议加两条工程规则：
- **冷却机制**：同一 task_id 在 cooldown 期间不重复触发
- **回滚机制**：`success_rate_delta < 0` 时不回灌新策略

---

## 5. 你们云端实现建议（非强制）

- 提交接口：HTTP/gRPC 均可
- 训练任务元数据至少带：`request_id/task_id/policy_version_before`
- Artifact 统一存储（S3/OSS/GCS）并返回可读 URL
- 训练结束通过 webhook/轮询任一方式回传主系统

---

## 6. 示例：自定义云端训练器骨架

```python
from rse.adapters.rl_trainer import RLTrainerAdapter
from rse.adapters.rl_contracts import TrainRequest, TrainResult, TrainingJobStatus

class CloudRLTrainer(RLTrainerAdapter):
    def submit(self, req: TrainRequest) -> str:
        # TODO: POST /train
        return "job-123"

    def status(self, job_id: str) -> TrainingJobStatus:
        # TODO: GET /train/{job_id}/status
        return TrainingJobStatus.RUNNING

    def fetch_result(self, job_id: str) -> TrainResult:
        # TODO: GET /train/{job_id}/result
        return TrainResult(
            request_id="req-xxx",
            job_id=job_id,
            status=TrainingJobStatus.SUCCEEDED,
            policy_version_after="pick_apple-v3",
            metrics={"success_rate_delta": 0.21},
            artifacts={"checkpoint": "s3://..."},
        )
```

---

## 7. 对齐清单（建议本周完成）

- [ ] task_id 字典对齐（主系统 vs RL 侧）
- [ ] reward 字段语义对齐（terms/penalty）
- [ ] scene constraints 字段对齐
- [ ] policy version 命名规则对齐
- [ ] 结果指标最小集合对齐
