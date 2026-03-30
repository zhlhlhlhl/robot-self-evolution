from __future__ import annotations

import time

from rse.core.models import TriggerConfig, TriggerDecision
from rse.loop.stats import FailureStats


class TrainingTrigger:
    def __init__(self, cfg: TriggerConfig):
        self.cfg = cfg
        self._last_trigger_ts: dict[str, float] = {}

    def evaluate(self, task_id: str, stats: FailureStats) -> TriggerDecision:
        total = stats.total_by_task.get(task_id, 0)
        if total < self.cfg.min_samples:
            return TriggerDecision(trigger=False, reason=f"insufficient_samples:{total}")

        fr = stats.failure_rate(task_id)
        if fr < self.cfg.trigger_failure_rate:
            return TriggerDecision(trigger=False, reason=f"low_failure_rate:{fr:.2f}")

        top = stats.top_failures(task_id, k=2)
        top_count = sum(c for _, c in top)
        fail_total = stats.fail_by_task.get(task_id, 0)
        concentration = (top_count / fail_total) if fail_total else 0.0
        if concentration < self.cfg.min_concentration:
            return TriggerDecision(trigger=False, reason=f"low_concentration:{concentration:.2f}")

        now = time.time()
        last = self._last_trigger_ts.get(task_id, 0)
        cooldown_s = self.cfg.cooldown_minutes * 60
        if now - last < cooldown_s:
            return TriggerDecision(trigger=False, reason="cooldown")

        self._last_trigger_ts[task_id] = now
        return TriggerDecision(
            trigger=True,
            train_task_id=task_id,
            reason="triggered",
            dominant_failures=[f for f, _ in top],
        )
