import subprocess
import fastf1
import pandas as pd
from pathlib import Path

def get_recent_event() -> tuple[int, str]:
    """
    Retrieve the most recent session.
    """

    # set fastf1 cache
    Path("data/raw/fastf1_cache").mkdir(parents=True, exist_ok=True)
    fastf1.Cache.enable_cache("data/raw/fastf1_cache")

    # get current time
    now = pd.Timestamp.now(tz="UTC")

    # retrieve events data
    events = fastf1.get_event_schedule(year=now.year)
    completed_events = events[events["Session3Date"] < now] # last session before race
    
    last_event = completed_events.iloc[-1]
    return now.year, last_event["EventName"]

def main():
    year, event_name = get_recent_event()
    print(f"Predicting the:{year} {event_name}")

    steps = [
        ["python", "python/get_fp_data.py", "--year", str(year)],
        ["Rscript", "R/model.R", event_name, str(year)],
        ["Rscript", "R/predict.R", event_name, str(year), "."]
    ]

    for cmd in steps:
        print(f"\n>>> {' '.join(cmd)}")
        result = subprocess.run(cmd, check=True)

if __name__ == "__main__":
    main()
