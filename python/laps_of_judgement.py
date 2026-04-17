import subprocess
import fastf1
import pandas as pd
from fastf1 import plotting
from pathlib import Path

def get_completed_events(year: int = None) -> pd.DataFrame:
    """
    Retrieve the most recent session.
    """

    # set fastf1 cache
    Path("data/raw/fastf1_cache").mkdir(parents=True, exist_ok=True)
    fastf1.Cache.enable_cache("data/raw/fastf1_cache")

    # get current time
    now = pd.Timestamp.now(tz="UTC")
    year = year or now.year

    # retrieve events data
    events = fastf1.get_event_schedule(year=year)
    completed_events = events[events["Session3Date"] < now] # last session before qualifying

    return completed_events

def get_team_colour(year: int):
    """
    Retrieve given year constructor team colours.

    Args:
        year (int): Season year to call.
    """
    # set fastf1 cache
    Path("data/raw/fastf1_cache").mkdir(parents=True, exist_ok=True)
    fastf1.Cache.enable_cache("data/raw/fastf1_cache")

    # retrieve session data
    session = fastf1.get_session(year, 1, "R")
    session.load(telemetry=False, weather=False, messages=False, laps=False)

    # collect team colours
    team_colours = {}
    for team in plotting.list_team_names(session):
          if team not in team_colours:
              team_colours[team] = plotting.get_team_color(team, session)

    # save team colours
    if team_colours:
        colours_path = Path("data") / f"team_colours_{year}.csv"
        pd.DataFrame(
            [{"Team": team, "Colour": colour} for team, colour in team_colours.items()]
        ).to_csv(colours_path, index=False)

def main():
    year = pd.Timestamp.now(tz="UTC").year
    event_name = get_completed_events().iloc[-1]["EventName"]
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
