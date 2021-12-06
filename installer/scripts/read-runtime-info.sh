set -euo pipefail
cat /proc/cmdline \
    | awk -v RS=" " '/^runtime_info/ {print gensub(/runtime_info="(.+)"/, "\\1", "g", $0);}' \
    | base64 -d
