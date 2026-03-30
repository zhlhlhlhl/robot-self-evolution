from __future__ import annotations


class RLTrainerAdapter:
    """TODO: 接入云端 RL 训练任务提交与结果回传。"""

    def trigger(self, task_id: str, failures: list[str]) -> dict:
        return {"submitted": True, "task_id": task_id, "failures": failures}
