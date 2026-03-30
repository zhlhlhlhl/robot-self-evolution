from __future__ import annotations

import random
from dataclasses import dataclass

from rse.core.models import (
    DoneCondition,
    FailureCode,
    JudgeConfig,
    SubTask,
    TaskMetrics,
    TaskStatus,
    TriggerConfig,
)
from rse.loop.judge import TaskJudge
from rse.loop.stats import FailureStats
from rse.loop.trigger import TrainingTrigger


@dataclass
class PipelineContext:
    judge: TaskJudge
    stats: FailureStats
    trigger: TrainingTrigger


def build_demo_tasks() -> list[SubTask]:
    return [
        SubTask(task_id="nav_to_apple_table", done_condition=DoneCondition(type="nav_reached"), timeout_s=40),
        SubTask(task_id="pick_apple", done_condition=DoneCondition(type="object_grasped"), timeout_s=45),
        SubTask(task_id="place_apple_on_plate", done_condition=DoneCondition(type="object_in_receptacle"), timeout_s=45),
        SubTask(task_id="pick_plate", done_condition=DoneCondition(type="object_grasped"), timeout_s=45),
        SubTask(task_id="nav_back", done_condition=DoneCondition(type="nav_reached"), timeout_s=40),
    ]


def simulate_one_episode(ctx: PipelineContext) -> list[SubTask]:
    tasks = build_demo_tasks()
    for t in tasks:
        t.metrics = TaskMetrics(elapsed_s=random.uniform(1.0, t.timeout_s + 10), progress=random.uniform(0.0, 1.0))
        # demo: manipulation tasks fail more often
        if t.task_id in {"pick_apple", "place_apple_on_plate", "pick_plate"} and random.random() < 0.45:
            t.status = TaskStatus.FAIL
            t.failure_code = random.choice([FailureCode.GRASP_FAILED, FailureCode.GRASP_SLIP, FailureCode.IK_FAILED])
        else:
            done = t.metrics.progress > 0.85 and t.metrics.elapsed_s <= t.timeout_s
            t = ctx.judge.update(t, now_s=t.metrics.elapsed_s, done_satisfied=done)
        ctx.stats.ingest(t)
    return tasks


def run_demo(episodes: int = 80) -> None:
    ctx = PipelineContext(
        judge=TaskJudge(JudgeConfig()),
        stats=FailureStats(),
        trigger=TrainingTrigger(TriggerConfig(min_samples=30, trigger_failure_rate=0.30, min_concentration=0.60)),
    )

    for _ in range(episodes):
        simulate_one_episode(ctx)

    focus = "pick_apple"
    decision = ctx.trigger.evaluate(focus, ctx.stats)
    print("=== RSE Demo Report ===")
    print(f"task={focus}")
    print(f"samples={ctx.stats.total_by_task.get(focus, 0)}")
    print(f"failure_rate={ctx.stats.failure_rate(focus):.2f}")
    print(f"top_failures={ctx.stats.top_failures(focus)}")
    print(f"trigger={decision.trigger}, reason={decision.reason}, dominant={decision.dominant_failures}")
