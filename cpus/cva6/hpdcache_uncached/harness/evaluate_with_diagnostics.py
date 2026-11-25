"""Run the shared uncached grader and report a signal stop as 128 plus the signal number."""

import subprocess
import sys


MODULE = "hpdcache_uncached"


def main():
    harness, answer = sys.argv[1:]
    status = subprocess.run([harness, MODULE, answer]).returncode
    return 128 - status if status < 0 else status


if __name__ == "__main__":
    sys.exit(main())
