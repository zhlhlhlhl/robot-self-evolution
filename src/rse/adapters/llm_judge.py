from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, Optional

from rse.adapters.llm_client import OpenAICompatibleClient, safe_json_loads
from rse.core.models import FailureCode, TaskStatus


@dataclass
class JudgeDecision:
    status: TaskStatus
    failure_code: Optional[FailureCode]
    confidence: float
    rationale: str


class LLMTaskJudge:
    SYSTEM_PROMPT = (
        "You are a robotics execution judge. "
        "Classify task state into running/success/fail and select failure_code if fail. "
        "Return STRICT JSON: {status, failure_code, confidence, rationale}."
    )

    def __init__(self, client: OpenAICompatibleClient):
        self.client = client

    def judge(self, task_id: str, observation: Dict[str, Any], telemetry: Dict[str, Any]) -> JudgeDecision:
        user_prompt = (
            f"task_id={task_id}\n"
            f"observation={observation}\n"
            f"telemetry={telemetry}\n"
            "failure_code must be one of: timeout,no_progress,planner_error,ik_failed,grasp_failed,grasp_slip,placement_failed,collision,safety_violation,perception_lost,tool_unavailable,unknown"
        )
        try:
            text = self.client.chat(self.SYSTEM_PROMPT, user_prompt, temperature=0.0)
            data = safe_json_loads(text)
            status = TaskStatus(data["status"])
            code = data.get("failure_code")
            failure_code = FailureCode(code) if code else None
            confidence = float(data.get("confidence", 0.0))
            return JudgeDecision(
                status=status,
                failure_code=failure_code,
                confidence=confidence,
                rationale=str(data.get("rationale", "")),
            )
        except Exception:
            return JudgeDecision(
                status=TaskStatus.RUNNING,
                failure_code=None,
                confidence=0.0,
                rationale="llm_judge_fallback",
            )
