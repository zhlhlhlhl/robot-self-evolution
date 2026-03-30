from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Dict

from rse.adapters.rl_contracts import TrainRequest, TrainResult, TrainingJobStatus


class RLTrainerAdapter(ABC):
    """RL 训练器模块化接口。

    你合作者的实现只需继承该抽象类，并填充 submit/status/fetch_result。
    """

    @abstractmethod
    def submit(self, req: TrainRequest) -> str:
        """提交训练任务，返回 job_id。"""

    @abstractmethod
    def status(self, job_id: str) -> TrainingJobStatus:
        """查询任务状态。"""

    @abstractmethod
    def fetch_result(self, job_id: str) -> TrainResult:
        """拉取训练结果（成功/失败都需要可追溯信息）。"""


class InMemoryRLTrainerAdapter(RLTrainerAdapter):
    """本地占位实现：用于联调主流程，不依赖云端。"""

    def __init__(self) -> None:
        self._jobs: Dict[str, TrainResult] = {}
        self._idx = 0

    def submit(self, req: TrainRequest) -> str:
        self._idx += 1
        job_id = f"job-{self._idx:04d}"
        self._jobs[job_id] = TrainResult(
            request_id=req.request_id,
            job_id=job_id,
            status=TrainingJobStatus.SUCCEEDED,
            policy_version_after=f"{req.task_id}-policy-v-next",
            metrics={"success_rate_delta": 0.18, "episodes": 20000},
            artifacts={"checkpoint": "s3://placeholder/checkpoint.pt"},
        )
        return job_id

    def status(self, job_id: str) -> TrainingJobStatus:
        result = self._jobs[job_id]
        return result.status

    def fetch_result(self, job_id: str) -> TrainResult:
        return self._jobs[job_id]
