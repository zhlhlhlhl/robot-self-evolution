from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict


@dataclass
class SimStepResult:
    done_satisfied: bool
    progress: float
    elapsed_s: float
    info: Dict[str, Any] = field(default_factory=dict)


class SimEnvAdapter(ABC):
    """仿真环境统一接口：你合作者只需对接这 3 个方法。"""

    @abstractmethod
    def reset(self, scene_spec: Dict[str, Any]) -> Dict[str, Any]:
        """加载场景并返回初始观测。"""

    @abstractmethod
    def execute_subtask(self, task_id: str, task_input: Dict[str, Any]) -> SimStepResult:
        """执行一个子任务并返回进展与完成信号。"""

    @abstractmethod
    def close(self) -> None:
        """释放资源。"""


class DummySimEnvAdapter(SimEnvAdapter):
    """本地联调占位实现。"""

    def reset(self, scene_spec: Dict[str, Any]) -> Dict[str, Any]:
        return {"ok": True, "scene": scene_spec}

    def execute_subtask(self, task_id: str, task_input: Dict[str, Any]) -> SimStepResult:
        # TODO: 用真实仿真结果替换
        return SimStepResult(done_satisfied=True, progress=1.0, elapsed_s=1.0, info={"task_id": task_id})

    def close(self) -> None:
        return
