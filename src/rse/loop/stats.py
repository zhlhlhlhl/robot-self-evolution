from __future__ import annotations

from collections import Counter, defaultdict

from rse.core.models import FailureCode, SubTask, TaskStatus


class FailureStats:
    def __init__(self) -> None:
        self.total_by_task: dict[str, int] = defaultdict(int)
        self.fail_by_task: dict[str, int] = defaultdict(int)
        self.fail_code_by_task: dict[str, Counter[str]] = defaultdict(Counter)

    def ingest(self, task: SubTask) -> None:
        self.total_by_task[task.task_id] += 1
        if task.status == TaskStatus.FAIL:
            self.fail_by_task[task.task_id] += 1
            code = task.failure_code.value if isinstance(task.failure_code, FailureCode) else "unknown"
            self.fail_code_by_task[task.task_id][code] += 1

    def failure_rate(self, task_id: str) -> float:
        total = self.total_by_task.get(task_id, 0)
        if total == 0:
            return 0.0
        return self.fail_by_task.get(task_id, 0) / total

    def top_failures(self, task_id: str, k: int = 2) -> list[tuple[str, int]]:
        return self.fail_code_by_task.get(task_id, Counter()).most_common(k)
