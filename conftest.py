import sys
from pathlib import Path

scripts_dir = Path(__file__).parent / "scripts"
if not scripts_dir.exists():
    raise RuntimeError(f"scripts directory not found at {scripts_dir}")
sys.path.insert(0, str(scripts_dir))
