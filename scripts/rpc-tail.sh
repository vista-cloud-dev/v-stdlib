#!/usr/bin/env bash
# rpc-tail.sh — live "tail -f" of VistA RPC traffic from the VSLRPCWRAP tap ring.
#
# Watch RPCs scroll to your terminal as CPRS (or anything) talks to VistA, so you
# can confirm the broker tap is actually firing. No MinIO, no S3 egress, no
# analysis — it reads the always-on capture ring ^XTMP("VSLTAP") directly.
#
# Transport: the sanctioned driver path only — `m vista exec` (m-driver-sdk ->
# m-ydb/m-iris). It never hand-rolls a raw container shell or in-process engine
# session, so it passes the org engine-access gate with no exemption marker.
#
# Prereqs on the target VistA (see docs/proposals/cprs-rpc-live-tail.md):
#   1. VSL* tap stack installed   (v pkg install)
#   2. broker patched             (v pkg wrap-rpc install --commit)
#   3. tap armed                  (captureOn true)  — S3 egress NOT required
#
# Usage:
#   scripts/rpc-tail.sh [--engine iris|ydb] [--transport remote|docker|local]
#                       [--interval SECONDS] [--backlog] [--no-color]
#   M=/path/to/m scripts/rpc-tail.sh        # override the `m` binary
#
# Ctrl-C to stop. Each row is one captured record:
#   SEQ   TIME      DUZ    DIR   RPC
set -euo pipefail

ENGINE="iris"
TRANSPORT="remote"
INTERVAL="0.7"
BACKLOG=0
M="${M:-m}"
COLOR=1
[ -t 1 ] || COLOR=0
[ -n "${NO_COLOR:-}" ] && COLOR=0

usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
	case "$1" in
		--engine)    ENGINE="${2:?}"; shift 2 ;;
		--transport) TRANSPORT="${2:?}"; shift 2 ;;
		--interval)  INTERVAL="${2:?}"; shift 2 ;;
		--backlog)   BACKLOG=1; shift ;;
		--no-color)  COLOR=0; shift ;;
		-h|--help)   usage 0 ;;
		*) echo "rpc-tail: unknown argument: $1" >&2; usage 1 ;;
	esac
done

command -v "$M" >/dev/null 2>&1 || { echo "rpc-tail: '$M' not on PATH (set M=/path/to/m)" >&2; exit 1; }

# Run one M command on the live VistA via the driver. Returns its device output.
mexec() { "$M" vista exec --engine "$ENGINE" --transport "$TRANSPORT" -o text "$1" 2>/dev/null; }

# Pretty-print "seq|ts|duz|dir|rpc|denied" rows; convert $HOROLOG ts -> HH:MM:SS.
fmt() {
	awk -F'|' -v color="$COLOR" '
		/^[0-9]+\|/ {
			split($2, h, ","); s = h[2] + 0
			t = sprintf("%02d:%02d:%02d", int(s/3600), int(s/60)%60, s%60)
			dim = color ? "\033[2m" : ""; red = color ? "\033[31m" : ""
			rst = color ? "\033[0m" : ""
			line = sprintf("%6s  %s  %-5s  %-4s  %s", $1, t, $3, $4, $5)
			if (($6 + 0) == 1) print red line "  DENIED" rst
			else if ($4 == "req") print dim line rst
			else print line
		}'
}

# Read current ring bounds (head = newest seq, tail = (oldest retained)-1).
read_bounds() {
	mexec 'write "B|",$$head^VSLTAP(),"|",$$tail^VSLTAP(),!' | sed -n 's/^B|//p' | head -1
}

bounds="$(read_bounds || true)"
if [ -z "$bounds" ]; then
	echo "rpc-tail: could not reach the VSLTAP ring on $ENGINE ($TRANSPORT)." >&2
	echo "          Is the VistA up, the stack installed, and the tap armed?" >&2
	exit 1
fi
head="${bounds%%|*}"; tail="${bounds##*|}"
[ "$BACKLOG" -eq 1 ] && cursor="$tail" || cursor="$head"

trap 'echo; echo "rpc-tail: stopped."; exit 0' INT TERM

echo "rpc-tail: watching $ENGINE ($TRANSPORT) — head=$head tail=$tail, starting at seq>$cursor"
[ "$head" -eq 0 ] && echo "rpc-tail: ring is empty — drive some RPCs (and check the tap is armed)."
printf '%6s  %-8s  %-5s  %-4s  %s\n' "SEQ" "TIME" "DUZ" "DIR" "RPC"
printf '%6s  %-8s  %-5s  %-4s  %s\n' "------" "--------" "-----" "----" "---"

# Poll loop: each tick fetch every committed record newer than the cursor,
# emit one line per record + a HEAD= sentinel, print, advance the cursor.
while :; do
	cmd="set h=\$\$head^VSLTAP() write \"HEAD=\",h,! \
for s=${cursor}+1:1:h quit:\$\$present^VSLTAP(s)=0  set z=\$\$hdr^VSLTAP(s,.o) \
write s,\"|\",\$get(o(\"ts\")),\"|\",\$get(o(\"duz\")),\"|\",\$get(o(\"direction\")),\"|\",\$get(o(\"rpc\")),\"|\",\$get(o(\"denied\")),!"
	if out="$(mexec "$cmd")"; then
		printf '%s\n' "$out" | fmt
		newhead="$(printf '%s\n' "$out" | sed -n 's/^HEAD=//p' | head -1)"
		[ -n "$newhead" ] && cursor="$newhead"
	else
		echo "rpc-tail: lost the engine — retrying…" >&2
	fi
	sleep "$INTERVAL"
done
