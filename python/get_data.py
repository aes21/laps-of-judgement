import fastf1
import pandas as pd
import argparse
from config import init_cache, SessionType
from laps_of_judgement import get_completed_events, get_team_colour
from pathlib import Path
from typing import Optional

init_cache()

def get_session_data(session_type: SessionType, year: int, event_name: Optional[str] = None, output_dir: str = "data/processed") -> None:
    """
    Retrieve a complete year's free practice session data from fastf1.

    Args:
        session_type (SessionType): The session type data to retrieve (e.g., `SessionType.P`).
        year (int): Session year.
        event_name(str): Optional. Target event name, if missing, will download the total season session data.
        output_dir (str): Output directory.
    """
    
    # retrieve events data
    events = get_completed_events(year=year)

    if event_name is not None:
        if event_name not in events["EventName"].values:
            raise ValueError(f"'{event_name}' not found for the {year} season.")
        events = events[events["EventName"] == event_name]

    # define fp sessions
    sessions = session_type.sessions
    all_laps = []

    # retrieve all available session lap data
    for en in events["EventName"]:
        for fp in sessions:
            try:
                session = fastf1.get_session(year, en, fp)
                session.load(telemetry=True, weather=False, messages=False, laps=True)
                laps = session.laps.copy()
                laps["RoundName"] = en
                laps["Session"] = fp
                laps["isSprint"] = (session.event.EventFormat == 'sprint_qualifying')
                all_laps.append(laps)
                print(f" Loaded {en} {fp}")
            except ValueError:
                continue
            except Exception as e:
                print(f" WARNING: Failed to load {en} {fp} due to: {e}")

    if not all_laps:
        raise RuntimeError("No lap data loaded - check connection to 'fastf1'.")
    
    # build data
    all_session_laps = pd.concat(all_laps, ignore_index=True)

    Path(output_dir).mkdir(parents=True, exist_ok=True)
    out_path = Path(output_dir) / f"all_{session_type.name.lower()}_laps_{year}.csv"
    all_session_laps.to_csv(out_path, index=False)
    print(f"\nSaved {year} {session_type.name} data to {out_path}")

    if not (Path("data") / f"team_colours_{year}.csv").exists():
        get_team_colour(year=year)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--session_type", type=str, choices = ["P", "Q", "R"], default = "P")
    parser.add_argument("--year", type=int, default=2025)
    parser.add_argument("--event_name", type=str)
    parser.add_argument("--output_dir", type=str, default="data/processed")
    args=parser.parse_args()
    get_session_data(SessionType[args.session_type], args.year, args.event_name, args.output_dir)
