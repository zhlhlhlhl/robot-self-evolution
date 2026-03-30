# RSE Interface Spec v1

## 1) Subtask Contract
每个子任务统一用以下结构：

```json
{
  "task_id": "pick_apple",
  "input": {
    "object": "apple",
    "source": "table_A",
    "target": "plate_1"
  },
  "done_condition": {
    "type": "object_in_receptacle",
    "object": "apple",
    "receptacle": "plate_1"
  },
  "timeout_s": 45,
  "status": "running",
  "failure_code": null,
  "metrics": {
    "elapsed_s": 12.4,
    "progress": 0.35
  }
}
```

必填字段：
- `task_id`：子任务唯一标识
- `input`：执行输入参数
- `done_condition`：完成判定条件
- `timeout_s`：超时阈值
- `status`：`running | success | fail`
- `failure_code`：失败码（成功/执行中时为 `null`）

## 2) Failure Code Taxonomy (v1)
- `timeout`
- `no_progress`
- `planner_error`
- `ik_failed`
- `grasp_failed`
- `grasp_slip`
- `placement_failed`
- `collision`
- `safety_violation`
- `perception_lost`
- `tool_unavailable`
- `unknown`

## 3) Judge Rules (MVP)
判定器每 `judge_tick_s` 秒更新一次：
1. 若 `done_condition` 满足 -> `success`
2. 若 `elapsed_s > timeout_s` -> `fail(timeout)`
3. 若连续 `no_progress_window_s` 时间进展 < `progress_epsilon` -> `fail(no_progress)`
4. 其他 -> `running`

## 4) Training Trigger Rule
仅在满足全部条件时触发训练：
- `sample_count >= min_samples`
- `failure_rate >= trigger_failure_rate`
- top-1/top-2 failure code 占比达到 `min_concentration`
- 距离上次训练超过冷却时间 `cooldown_minutes`

输出：
- `train_task_id`
- `dominant_failures`
- `scenario_constraints`
- `policy_version_before`
