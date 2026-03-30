# 合作者集成作战手册（仿真环境 + RL 训练）

目标：让你合作者能在最短时间把“当前仿真环境/RL训练系统”接到 RSE 主框架，而不是重写一套新系统。

---

## A. 先说结论：要改哪些代码（最关键）

### 你这边（主框架）需要改
1. `src/rse/adapters/navigation_tool.py`
   - 接入你现有导航 tool 的真实调用。
2. `src/rse/adapters/vla_manipulation.py`
   - 接入 manipulation 的 VLA 执行。
3. `src/rse/loop/pipeline.py`（后续可弱化）
   - 目前是随机模拟；逐步迁移到 `runtime.py` 的真实仿真执行。
4. `src/rse/loop/runtime.py`（新增）
   - 用仿真环境实际执行子任务链。

### 合作者（仿真+RL）需要改
1. 新建 `CloudSimEnvAdapter`（继承 `SimEnvAdapter`）
   - 文件可放：`src/rse/adapters/sim_env_cloud.py`
   - 实现：`reset` / `execute_subtask` / `close`
2. 新建 `CloudRLTrainer`（继承 `RLTrainerAdapter`）
   - 文件已提供：`src/rse/adapters/rl_trainer_cloud.py`
   - 实现：`submit` / `status` / `fetch_result`
3. 新建/使用 `CloudSimEnvAdapter`（继承 `SimEnvAdapter`）
   - 文件已提供：`src/rse/adapters/sim_env_cloud.py`
   - 实现：`reset` / `execute_subtask` / `close`

---

## B. 在仿真里执行 RSE 框架（标准路径）

1) 构建子任务链（SubTask）
- 例：`nav_to_apple_table -> pick_apple -> place_apple_on_plate -> pick_plate -> nav_back`

2) 调用 `EpisodeRunner.run_once(tasks, scene_spec)`
- `scene_spec` 由仿真侧定义（物体初始位置、随机化参数、种子）

3) `SimEnvAdapter.execute_subtask` 返回
- `done_satisfied`
- `progress`
- `elapsed_s`

4) Judge 自动判定
- `success/running/fail`
- 统计模块自动累计失败率与 failure code

5) 触发训练
- `TrainingTrigger` 达到阈值后
- 通过 `RLTrainerAdapter` 提交训练请求
- 返回 `policy_version_after` 后再回灌

---

## C. 仿真环境对接最低要求（避免卡死）

合作者环境必须满足这 5 点：
1. **可编程 reset**：支持按 `scene_spec` 重置
2. **可调用子任务执行**：给 task_id + input 就能执行
3. **可观测进展**：返回 progress（0~1）
4. **可计时**：返回 elapsed_s
5. **可追踪日志**：失败时能给 reason / logs

如果缺任意一项，闭环会不稳定或无法训练触发。

---

## D. 版本化与回灌规则（务必统一）

- 训练请求必须带：`policy_version_before`
- 训练结果必须回：`policy_version_after`
- 自动回灌门槛：
  - `success_rate_delta > 0`
  - `safety_violation_rate` 不劣化
- 不满足则只归档，不上线

---

## E. 一周落地节奏（可直接执行）

### Day 1
- 对齐 `task_id` 字典与 `failure_code`
- 跑通 `DummySimEnvAdapter + InMemoryRLTrainerAdapter`

### Day 2-3
- 合作者实现 `CloudSimEnvAdapter`
- 先打通 `reset + execute_subtask`

### Day 4
- 实现 `CloudRLTrainer.submit/status/result`
- 跑通一次训练任务提交和结果回传

### Day 5
- 做 before/after 对比报告（N=100 episodes）
- 决定是否回灌新策略

---

## F. 最小联调验收标准（通过即算集成完成）

- [ ] 一次 episode 能从仿真真实执行完任务链
- [ ] 至少一个子任务能产出稳定 failure stats
- [ ] 触发器可自动发起训练请求
- [ ] RL 结果可回传并带 `policy_version_after`
- [ ] 可输出 before/after 指标对比
