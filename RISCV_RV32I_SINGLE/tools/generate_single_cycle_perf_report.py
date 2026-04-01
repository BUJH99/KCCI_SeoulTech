from __future__ import annotations

import pathlib
import sys


PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[1]
REPO_ROOT = PROJECT_ROOT.parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from templates.contexts.timing_verification.adapters.python.riscv_timing_analysis.single_cycle import run


if __name__ == "__main__":
    sys.exit(run(PROJECT_ROOT))
