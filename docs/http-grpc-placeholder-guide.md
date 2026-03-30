# HTTP/gRPC 占位实现说明

本文档说明如何使用仓库内新增的“云端占位适配器”，让合作者快速把现有仿真环境和 RL 训练服务接到 RSE。

## 1. 新增文件

- `src/rse/adapters/sim_env_cloud.py`
  - `CloudSimEnvAdapter`（HTTP）
- `src/rse/adapters/rl_trainer_cloud.py`
  - `CloudRLTrainer`（HTTP）
- `configs/cloud.example.yaml`
  - 云端地址、token、超时示例

## 2. 什么是占位实现

占位实现不是最终生产版本，而是先把“接口和数据契约”固化下来，保证：
- 主框架能联调
- 合作者后端能对齐字段
- 后续只替换 endpoint/认证/错误处理细节

## 3. 当前默认 HTTP 端点约定

### 仿真服务
- `POST /sim/reset`
- `POST /sim/execute`
- （可选）`POST /sim/close`

`/sim/execute` 返回至少包含：
- `done_satisfied: bool`
- `progress: float` (0~1)
- `elapsed_s: float`
- `info: object`

### RL 服务
- `POST /rl/train`
- `GET /rl/train/{job_id}/status`
- `GET /rl/train/{job_id}/result`

`/rl/train/{job_id}/result` 返回至少包含：
- `request_id`
- `job_id`
- `status`
- `policy_version_after` (成功时)
- `metrics`
- `artifacts`
- `error` (失败时)

## 4. 如何替换成真实后端

1. 保持类名和方法签名不变（`submit/status/fetch_result` 等）
2. 将 `_request/_post` 替换为你们已有的 HTTP 客户端或 gRPC stub
3. 保持 `TrainRequest/TrainResult` 字段语义一致
4. 在 `configs/cloud.example.yaml` 填真实地址和 token

## 5. gRPC 对接建议

如果你们后端是 gRPC：
- 保留 `CloudSimEnvAdapter` / `CloudRLTrainer` 对外方法不变
- 在内部改为调用 protobuf 生成的 client
- 在适配层完成 protobuf <-> dataclass 的转换

这样上层 RSE 逻辑无需改动。

## 6. 工程建议

- 先打通 happy path，再补重试/熔断
- status/result 接口建议幂等
- metrics 字段做版本化（如 `metrics_schema_version`）
- 所有训练任务强制记录 `request_id/task_id/policy_version_before`
