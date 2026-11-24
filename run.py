"""Start DM7 Link from source: `python3 run.py [console ip] [options]`."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from dm7link.__main__ import main  # noqa: E402

if __name__ == "__main__":
    raise SystemExit(main())
