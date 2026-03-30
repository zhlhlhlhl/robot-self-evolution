from __future__ import annotations

from dataclasses import dataclass
from typing import List

from rse.adapters.sim_env import SimEnvAdapter
from rse.core.models import SubTask, TaskMetrics
from rse.loop.judge import TaskJudge
from rse.loop.stats import FailureStats


@dataclass
class RuntimeContext:
    env: SimEnvAdapter
    judge: TaskJudge
    stats: FailureStats


class EpisodeRunner:
    """在仿真中执行 RSE 子任务链的最小运行时。"""

    def __init__(self, ctx: RuntimeContext):
        self.ctx = ctx

    def run_once(self, tasks: List[SubTask], scene_spec: dict) -> List[SubTask]:
        self.ctx.env.reset(scene_spec)
        now_s = 0.0

        for t in tasks:
            step = self.ctx.env.execute_subtask(t.task_id, t.input)
            t.metrics = TaskMetrics(elapsed_s=step.elapsed_s, progress=step.progress)
            now_s += step.elapsed_s
            self.ctx.judge.update(t, now_s=now_s, done_satisfied=step.done_satisfied)
            self.ctx.stats.ingest(t)

        return tasks
