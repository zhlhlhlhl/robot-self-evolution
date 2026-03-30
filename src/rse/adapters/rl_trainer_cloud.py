from __future__ import annotations

import json
import urllib.request
from typing import Any, Dict, Optional

from rse.adapters.rl_contracts import TrainRequest, TrainResult, TrainingJobStatus
from rse.adapters.rl_trainer import RLTrainerAdapter


class CloudRLTrainer(RLTrainerAdapter):
    """HTTP 占位实现：对接云端 RL 训练服务。"""

    def __init__(self, base_url: str, token: str = "", timeout_s: float = 10.0):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.timeout_s = timeout_s

    def _request(self, method: str, path: str, payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        url = f"{self.base_url}{path}"
        data = json.dumps(payload).encode("utf-8") if payload is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Content-Type", "application/json")
        if self.token:
            req.add_header("Authorization", f"Bearer {self.token}")
        with urllib.request.urlopen(req, timeout=self.timeout_s) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def submit(self, req: TrainRequest) -> str:
        # 约定端点：POST /rl/train
        payload = {
            "request_id": req.request_id,
            "task_id": req.task_id,
            "dominant_failures": req.dominant_failures,
            "scenario": {
                "scene_type": req.scenario.scene_type,
                "object_set": req.scenario.object_set,
                "domain_randomization": req.scenario.domain_randomization,
                "constraints": req.scenario.constraints,
            },
            "reward": {
                "version": req.reward.version,
                "terms": req.reward.terms,
                "safety_penalties": req.reward.safety_penalties,
            },
            "policy_version_before": req.policy_version_before,
            "budget_hours": req.budget_hours,
            "metadata": req.metadata,
        }
        out = self._request("POST", "/rl/train", payload)
        return str(out["job_id"])

    def status(self, job_id: str) -> TrainingJobStatus:
        # 约定端点：GET /rl/train/{job_id}/status
        out = self._request("GET", f"/rl/train/{job_id}/status")
        return TrainingJobStatus(out["status"])

    def fetch_result(self, job_id: str) -> TrainResult:
        # 约定端点：GET /rl/train/{job_id}/result
        out = self._request("GET", f"/rl/train/{job_id}/result")
        return TrainResult(
            request_id=out["request_id"],
            job_id=out["job_id"],
            status=TrainingJobStatus(out["status"]),
            policy_version_after=out.get("policy_version_after"),
            metrics=out.get("metrics", {}),
            artifacts=out.get("artifacts", {}),
            error=out.get("error"),
        )
