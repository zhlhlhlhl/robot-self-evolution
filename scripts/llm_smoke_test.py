from rse.adapters.llm_client import OpenAICompatibleClient
from rse.adapters.llm_judge import LLMTaskJudge
from rse.adapters.llm_planner import LLMTaskPlanner


def main() -> None:
    client = OpenAICompatibleClient.from_env()

    planner = LLMTaskPlanner(client)
    subtasks = planner.plan(
        instruction="让机器人去拿起苹果放在盘子里，再把盘子拿回给我",
        robot_context="nav tool available; VLA for manipulation",
    )
    print("planner subtasks:")
    for s in subtasks:
        print("-", s.task_id, s.timeout_s, s.done_condition.type)

    judge = LLMTaskJudge(client)
    decision = judge.judge(
        task_id="pick_apple",
        observation={"gripper": "closed", "apple_visible": True},
        telemetry={"progress": 0.42, "elapsed_s": 12.0},
    )
    print("judge decision:", decision)


if __name__ == "__main__":
    main()
