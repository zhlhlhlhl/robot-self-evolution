from __future__ import annotations

from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


class TaskStatus(str, Enum):
    RUNNING = "running"
    SUCCESS = "success"
    FAIL = "fail"


class FailureCode(str, Enum):
    TIMEOUT = "timeout"
    NO_PROGRESS = "no_progress"
    PLANNER_ERROR = "planner_error"
    IK_FAILED = "ik_failed"
    GRASP_FAILED = "grasp_failed"
    GRASP_SLIP = "grasp_slip"
    PLACEMENT_FAILED = "placement_failed"
    COLLISION = "collision"
    SAFETY_VIOLATION = "safety_violation"
    PERCEPTION_LOST = "perception_lost"
    TOOL_UNAVAILABLE = "tool_unavailable"
    UNKNOWN = "unknown"


class DoneCondition(BaseModel):
    type: str
    payload: dict[str, Any] = Field(default_factory=dict)


class TaskMetrics(BaseModel):
    elapsed_s: float = 0.0
    progress: float = 0.0


class SubTask(BaseModel):
    task_id: str
    input: dict[str, Any] = Field(default_factory=dict)
    done_condition: DoneCondition
    timeout_s: int = 60
    status: TaskStatus = TaskStatus.RUNNING
    failure_code: Optional[FailureCode] = None
    metrics: TaskMetrics = Field(default_factory=TaskMetrics)


class JudgeConfig(BaseModel):
    judge_tick_s: float = 1.0
    no_progress_window_s: float = 8.0
    progress_epsilon: float = 0.02


class TriggerConfig(BaseModel):
    min_samples: int = 30
    trigger_failure_rate: float = 0.30
    min_concentration: float = 0.60
    cooldown_minutes: int = 60


class TriggerDecision(BaseModel):
    trigger: bool
    train_task_id: Optional[str] = None
    reason: Optional[str] = None
    dominant_failures: list[str] = Field(default_factory=list)
