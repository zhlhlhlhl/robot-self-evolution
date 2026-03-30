from __future__ import annotations

from collections import deque

from rse.core.models import FailureCode, JudgeConfig, SubTask, TaskStatus


class TaskJudge:
    def __init__(self, cfg: JudgeConfig):
        self.cfg = cfg
        self._progress_window: dict[str, deque[tuple[float, float]]] = {}

    def update(self, task: SubTask, now_s: float, done_satisfied: bool) -> SubTask:
        if task.status in {TaskStatus.SUCCESS, TaskStatus.FAIL}:
            return task

        if done_satisfied:
            task.status = TaskStatus.SUCCESS
            task.failure_code = None
            return task

        if task.metrics.elapsed_s > task.timeout_s:
            task.status = TaskStatus.FAIL
            task.failure_code = FailureCode.TIMEOUT
            return task

        buf = self._progress_window.setdefault(task.task_id, deque())
        buf.append((now_s, task.metrics.progress))
        while buf and now_s - buf[0][0] > self.cfg.no_progress_window_s:
            buf.popleft()

        if len(buf) >= 2:
            progress_delta = buf[-1][1] - buf[0][1]
            if progress_delta < self.cfg.progress_epsilon:
                task.status = TaskStatus.FAIL
                task.failure_code = FailureCode.NO_PROGRESS
                return task

        task.status = TaskStatus.RUNNING
        return task
