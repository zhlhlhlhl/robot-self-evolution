from __future__ import annotations


class VLAManipulationAdapter:
    """TODO: 接入 VLA 模型推理与执行。"""

    def run(self, action: str, payload: dict) -> dict:
        return {"ok": True, "action": action, "payload": payload}
