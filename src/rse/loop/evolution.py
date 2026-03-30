from __future__ import annotations

import uuid
from typing import Optional

from rse.adapters.rl_contracts import RewardSpec, ScenarioSpec, TrainRequest, TrainResult
from rse.adapters.rl_trainer import RLTrainerAdapter
from rse.loop.stats import FailureStats
from rse.loop.trigger import TrainingTrigger


class EvolutionOrchestrator:
    """把失败统计结果转成可提交给 RL 团队的标准请求。"""

    def __init__(self, trigger: TrainingTrigger, trainer: RLTrainerAdapter):
        self.trigger = trigger
        self.trainer = trainer

    def maybe_train(self, task_id: str, stats: FailureStats) -> Optional[TrainResult]:
        decision = self.trigger.evaluate(task_id, stats)
        if not decision.trigger:
            return None

        req = TrainRequest(
            request_id=str(uuid.uuid4()),
            task_id=task_id,
            dominant_failures=decision.dominant_failures,
            scenario=ScenarioSpec(
                scene_type="tabletop_manipulation",
                object_set=["apple", "plate"],
                constraints={"task_id": task_id, "focus_failures": decision.dominant_failures},
            ),
            reward=RewardSpec(
                version="v1",
                terms=[
                    {"name": "task_success", "weight": 1.0},
                    {"name": "time_efficiency", "weight": 0.2},
                ],
                safety_penalties=[
                    {"name": "collision", "weight": -1.0},
                ],
            ),
            policy_version_before="baseline-v1",
        )

        job_id = self.trainer.submit(req)
        return self.trainer.fetch_result(job_id)
