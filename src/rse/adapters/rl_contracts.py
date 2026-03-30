from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class TrainingJobStatus(str, Enum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELED = "canceled"


@dataclass
class ScenarioSpec:
    """训练场景约束（由失败挖掘模块产出，供 RL 侧生成资产/环境）。"""

    scene_type: str
    object_set: List[str] = field(default_factory=list)
    domain_randomization: Dict[str, Any] = field(default_factory=dict)
    constraints: Dict[str, Any] = field(default_factory=dict)


@dataclass
class RewardSpec:
    """Reward 设计接口（可由 LLM 辅助生成）。"""

    version: str
    terms: List[Dict[str, Any]] = field(default_factory=list)
    safety_penalties: List[Dict[str, Any]] = field(default_factory=list)


@dataclass
class TrainRequest:
    """主系统 -> RL 训练器 请求体。"""

    request_id: str
    task_id: str
    dominant_failures: List[str]
    scenario: ScenarioSpec
    reward: RewardSpec
    policy_version_before: str
    budget_hours: float = 4.0
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class TrainResult:
    """RL 训练器 -> 主系统 结果体。"""

    request_id: str
    job_id: str
    status: TrainingJobStatus
    policy_version_after: Optional[str] = None
    metrics: Dict[str, Any] = field(default_factory=dict)
    artifacts: Dict[str, str] = field(default_factory=dict)
    error: Optional[str] = None
