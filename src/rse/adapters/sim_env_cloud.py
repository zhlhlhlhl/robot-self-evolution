from __future__ import annotations

import json
import urllib.request
from typing import Any, Dict

from rse.adapters.sim_env import SimEnvAdapter, SimStepResult


class CloudSimEnvAdapter(SimEnvAdapter):
    """HTTP 占位实现：把仿真环境当成远端服务调用。"""

    def __init__(self, base_url: str, token: str = "", timeout_s: float = 10.0):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.timeout_s = timeout_s

    def _post(self, path: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        url = f"{self.base_url}{path}"
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data, method="POST")
        req.add_header("Content-Type", "application/json")
        if self.token:
            req.add_header("Authorization", f"Bearer {self.token}")
        with urllib.request.urlopen(req, timeout=self.timeout_s) as resp:
            return json.loads(resp.read().decode("utf-8"))

    def reset(self, scene_spec: Dict[str, Any]) -> Dict[str, Any]:
        # 约定端点：POST /sim/reset
        return self._post("/sim/reset", {"scene_spec": scene_spec})

    def execute_subtask(self, task_id: str, task_input: Dict[str, Any]) -> SimStepResult:
        # 约定端点：POST /sim/execute
        out = self._post("/sim/execute", {"task_id": task_id, "task_input": task_input})
        return SimStepResult(
            done_satisfied=bool(out.get("done_satisfied", False)),
            progress=float(out.get("progress", 0.0)),
            elapsed_s=float(out.get("elapsed_s", 0.0)),
            info=out.get("info", {}),
        )

    def close(self) -> None:
        # 可选：POST /sim/close
        return
