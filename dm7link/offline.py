"""OFFLINE in DM7 Link: the desk saved in the open show file in place of the console.

The worker and the connection are the panel's (`dm7gui.offline`); here the desk comes from the
show file (`ShowFiles.image`), not from a kept last console.
"""
from __future__ import annotations

from dm7gui.offline import OfflineConnection as LinkConnection  # noqa: F401
from dm7gui.offline import OfflineWorker as LinkWorker  # noqa: F401
