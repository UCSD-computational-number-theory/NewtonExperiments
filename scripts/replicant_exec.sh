#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
port_file="$project_dir/REPLICANT_PORT"

if [[ ! -f "$port_file" ]]; then
    echo "REPLICANT_PORT not found. Start the REPLicant server first." >&2
    exit 1
fi

printf '%s' "$*" | nc -N localhost "$(<"$port_file")"
