from enum import Enum
from pathlib import Path
import fastf1

# cache directory
CACHE_DIR = Path("data/raw/fastf1_cache")

def init_cache():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    fastf1.Cache.enable_cache(str(CACHE_DIR))

class SessionType(Enum):
    P = ["FP1", "FP2", "FP3"]
    Q = ["Q"]
    R = ["R"]

    @property
    def sessions(self):
        return self.value