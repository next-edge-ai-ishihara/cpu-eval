import os
from pathlib import Path
import tempfile


def port_work_root() -> Path:
    configured = os.environ.get("CPU_EVAL_PORT_RAM_ROOT")
    root = Path(configured or "/dev/shm")
    if configured or root.is_dir():
        if not os.statvfs(root).f_flag & os.ST_NOEXEC:
            return root
    for directory in (Path(tempfile.gettempdir()), Path("/tmp")):
        if directory.is_dir() and not os.statvfs(directory).f_flag & os.ST_NOEXEC:
            return directory
    raise OSError("no executable temporary directory is available for the port simulator")
