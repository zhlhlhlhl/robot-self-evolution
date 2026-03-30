from __future__ import annotations


class NavigationToolAdapter:
    """TODO: 接入你们已有导航 tool。"""

    def run(self, target: str) -> dict:
        return {"ok": True, "target": target}
