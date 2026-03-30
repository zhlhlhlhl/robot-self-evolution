from __future__ import annotations

from typing import List

from rse.adapters.llm_client import OpenAICompatibleClient, safe_json_loads
from rse.core.models import DoneCondition, FailureCode, SubTask


class LLMTaskPlanner:
    """Use LLM to decompose high-level instruction into SubTask list."""

    SYSTEM_PROMPT = (
        "You are a robotics task planner. "
        "Output STRICT JSON with key subtasks (array). "
        "Each item must contain: task_id, input, done_condition{type,payload}, timeout_s."
    )

    def __init__(self, client: OpenAICompatibleClient):
        self.client = client

    def plan(self, instruction: str, robot_context: str = "") -> List[SubTask]:
        user_prompt = (
            f"Instruction: {instruction}\n"
            f"Robot context: {robot_context}\n"
            "Return JSON object: {\"subtasks\": [...]} only."
        )
        try:
            text = self.client.chat(self.SYSTEM_PROMPT, user_prompt, temperature=0.0)
            data = safe_json_loads(text)
            out: List[SubTask] = []
            for item in data.get("subtasks", []):
                out.append(
                    SubTask(
                        task_id=item["task_id"],
                        input=item.get("input", {}),
                        done_condition=DoneCondition(**item["done_condition"]),
                        timeout_s=int(item.get("timeout_s", 60)),
                    )
                )
            if out:
                return out
        except Exception:
            pass

        # fallback minimal safe plan
        return [
            SubTask(
                task_id="planner_fallback",
                input={"instruction": instruction},
                done_condition=DoneCondition(type="manual_review", payload={}),
                timeout_s=20,
                failure_code=FailureCode.PLANNER_ERROR,
            )
        ]
