set -euo pipefail
cat /proc/cmdline \
    | awk -v RS=" " '/^disk_key/ {print gensub(/disk_key="(.+)"/, "\\1", "g", $0);}' \
    | base64 -d
