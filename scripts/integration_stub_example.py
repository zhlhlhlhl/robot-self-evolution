"""占位集成示例：展示如何实例化 CloudSimEnvAdapter / CloudRLTrainer。"""

from rse.adapters.rl_trainer_cloud import CloudRLTrainer
from rse.adapters.sim_env_cloud import CloudSimEnvAdapter


def main() -> None:
    sim = CloudSimEnvAdapter(base_url="http://localhost:8081", token="", timeout_s=15)
    rl = CloudRLTrainer(base_url="http://localhost:8091", token="", timeout_s=20)

    print("sim adapter:", sim.base_url)
    print("rl adapter:", rl.base_url)
    print("next: replace endpoints/token with collaborator backend")


if __name__ == "__main__":
    main()
