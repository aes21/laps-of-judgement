import fastf1
import pandas as pd
import argparse
from config import init_cache, SessionType
from laps_of_judgement import get_completed_events, get_team_colour
from pathlib import Path

init_cache()

def get_session_data(session_type: SessionType, year: int, output_dir: str = "data/processed") -> None:
    """
    Retrieve a complete year's free practice session data from fastf1.

    Args:
        session_type (SessionType): The session type data to retrieve (e.g., `SessionType.P`).
        year (int): Session year.
        output_dir (str): Output directory.
    """
    
    # retrieve events data
    events = get_completed_events(year=year)

    # define fp sessions
    sessions = session_type.value
    all_laps = []

    # retrieve all available session lap data
    for event_name in events["EventName"]:
        for fp in sessions:
            try:
                session = fastf1.get_session(year, event_name, fp)
                session.load(telemetry=True, weather=False, messages=False, laps=True)
                laps = session.laps.copy()
                laps["RoundName"] = event_name
                laps["Session"] = fp
                all_laps.append(laps)
                print(f" Loaded {event_name} {fp}")
            except ValueError:
                continue
            except Exception as e:
                print(f" WARNING: Failed to load {event_name} {fp} due to: {e}")

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
    parser.add_argument("--output_dir", type=str, default="data/processed")
    args=parser.parse_args()
    get_session_data(SessionType[args.session_type], args.year, args.output_dir)
