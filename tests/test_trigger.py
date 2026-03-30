from rse.core.models import TriggerConfig
from rse.loop.stats import FailureStats
from rse.loop.trigger import TrainingTrigger


def test_trigger_no_samples():
    stats = FailureStats()
    trg = TrainingTrigger(TriggerConfig(min_samples=10))
    d = trg.evaluate("pick_apple", stats)
    assert d.trigger is False
