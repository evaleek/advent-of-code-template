#!/usr/bin/env bash

# ./fetch.sh YYYY DAY
# ./fetch.sh 2015 1

set -euo pipefail

YEAR="$1"
DAY="$2"

COOKIE_FILE="$HOME/.config/aoc/session.cookie"
OUTDIR="input/${YEAR}"
OUTFILE="${OUTDIR}/day$(printf "%02d" "$DAY").txt"

mkdir -p "$OUTDIR"

if [[ ! -f "$COOKIE_FILE" ]]; then
    echo "Found no session cookie file at: $COOKIE_FILE"
    exit 1
fi

SESSION=$(cat "$COOKIE_FILE")

curl "https://adventofcode.com/${YEAR}/day/${DAY}/input" \
    -H "Cookie: session=${SESSION}" \
    --compressed \
    -o "$OUTFILE"

echo "Wrote input to $OUTFILE"
