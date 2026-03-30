from rse.adapters.sim_env import DummySimEnvAdapter
from rse.core.models import DoneCondition, JudgeConfig, SubTask
from rse.loop.judge import TaskJudge
from rse.loop.runtime import EpisodeRunner, RuntimeContext
from rse.loop.stats import FailureStats


def build_tasks() -> list[SubTask]:
    return [
        SubTask(task_id="nav_to_apple_table", done_condition=DoneCondition(type="nav_reached"), timeout_s=40),
        SubTask(task_id="pick_apple", done_condition=DoneCondition(type="object_grasped"), timeout_s=45),
        SubTask(task_id="place_apple_on_plate", done_condition=DoneCondition(type="object_in_receptacle"), timeout_s=45),
    ]


if __name__ == "__main__":
    ctx = RuntimeContext(env=DummySimEnvAdapter(), judge=TaskJudge(JudgeConfig()), stats=FailureStats())
    runner = EpisodeRunner(ctx)
    tasks = runner.run_once(build_tasks(), scene_spec={"scene": "tabletop_v1"})
    for t in tasks:
        print(t.task_id, t.status.value, t.failure_code)
