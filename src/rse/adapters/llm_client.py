from __future__ import annotations

import json
import os
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, List, Optional


@dataclass
class LLMConfig:
    base_url: str
    api_key: str
    model: str
    timeout_s: float = 30.0


class OpenAICompatibleClient:
    """OpenAI-compatible chat client.

    Supports Qwen-VL when provider exposes OpenAI-compatible endpoint.
    """

    def __init__(self, cfg: LLMConfig):
        self.cfg = cfg

    @classmethod
    def from_env(cls) -> "OpenAICompatibleClient":
        base_url = os.getenv("RSE_LLM_BASE_URL", "")
        api_key = os.getenv("RSE_LLM_API_KEY", "")
        model = os.getenv("RSE_LLM_MODEL", "")
        timeout_s = float(os.getenv("RSE_LLM_TIMEOUT_S", "30"))
        if not base_url or not api_key or not model:
            raise ValueError("Missing RSE_LLM_BASE_URL / RSE_LLM_API_KEY / RSE_LLM_MODEL")
        return cls(LLMConfig(base_url=base_url, api_key=api_key, model=model, timeout_s=timeout_s))

    def chat(self, system_prompt: str, user_prompt: str, temperature: float = 0.0, response_format: Optional[Dict[str, Any]] = None) -> str:
        payload: Dict[str, Any] = {
            "model": self.cfg.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": temperature,
        }
        if response_format is not None:
            payload["response_format"] = response_format

        url = self.cfg.base_url.rstrip("/") + "/chat/completions"
        req = urllib.request.Request(url=url, data=json.dumps(payload).encode("utf-8"), method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {self.cfg.api_key}")

        with urllib.request.urlopen(req, timeout=self.cfg.timeout_s) as resp:
            out = json.loads(resp.read().decode("utf-8"))

        return out["choices"][0]["message"]["content"]


def safe_json_loads(text: str) -> Dict[str, Any]:
    text = text.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text)
