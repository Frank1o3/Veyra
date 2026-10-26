#!/bin/sh
# Exit 0 = internet reachable. Exit 1 = not yet (systemd skips the service quietly).
for _ in $(seq 1 12); do
    curl -fsI --max-time 5 https://aur.archlinux.org >/dev/null 2>&1 && exit 0
    sleep 5
done
exit 1