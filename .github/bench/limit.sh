#!/usr/bin/env bash
# Temporary benchmark: bash .github/bench/limit.sh <name> <server command...>
# Server runs in the "box" image pinned to CPU 0 with 2 GB and no swap; k6 runs on CPUs 1-3.
# 1) limit search with load-scaled.js (THINK_SCALE=0.1, so 1 VU ~= 10 users): warm-up, x1.5 steps until fail, 2 bisections
# 2) one run of the unmodified think time at 10,000 VUs (connection-heavy, like direct mode)
set -uo pipefail
NAME=$1; shift
ROOT=$PWD
OUT=/tmp/bench-$NAME.txt
: > "$OUT"

start_server() {
    docker rm -f srv >/dev/null 2>&1
    rm -rf /tmp/db && mkdir -p /tmp/db && cp seed/feed.db /tmp/db/feed.db && chmod -R 777 /tmp/db
    docker run -d --name srv --cpuset-cpus=0 --cpus=1 --memory=2g --memory-swap=2g --network host \
        --ulimit nofile=65535:65535 -v "$ROOT":/repo -v /tmp/db:/db \
        -e SQLITE_PATH=/db/feed.db -e JWT_SECRET=twelve-dollar-challenge -e HOST=127.0.0.1 -e PORT=3000 \
        box "$@" >/dev/null
    for _ in $(seq 240); do curl -sf http://127.0.0.1:3000/health >/dev/null && return 0; sleep 0.25; done
    echo "server not healthy"; docker logs srv | tail -20; exit 1
}

cpu_s() { docker exec srv awk '/usage_usec/ { printf "%.1f", $2 / 1000000 }' /sys/fs/cgroup/cpu.stat; }
hwm_mib() { docker exec srv awk '/VmHWM/ { printf "%d", $2 / 1024 }' /proc/1/status; }

# step <vus> <hold> <ramp> <think_scale> -> prints a result line, returns k6's exit code
step() {
    local c0 c1 rc log
    c0=$(cpu_s)
    log=$(ulimit -n 65535; taskset -c 1-3 k6 run --quiet -e BASE_URL=http://127.0.0.1:3000 -e THINK_SCALE="$4" \
        -e TOKENS="$ROOT/seed/tokens.json" -e VUS="$1" -e DURATION="$2" -e RAMP_UP="$3" .github/bench/load-scaled.js 2>&1)
    rc=$?
    c1=$(cpu_s)
    local dur fail reqs
    dur=$(echo "$log" | grep -E "http_req_duration\.{3}" | head -1 | sed -E 's/.*: //; s/ +/ /g')
    fail=$(echo "$log" | grep -E "http_req_failed\.{3}" | head -1 | sed -E 's/.*: //; s/ +/ /g')
    reqs=$(echo "$log" | grep -E "http_reqs\.{3}" | head -1 | sed -E 's/.*: //; s/ +/ /g')
    local verdict=PASS; [ "$rc" = 0 ] || verdict="FAIL($rc)"
    printf '%s vus=%s scale=%s %s | %s | failed %s | reqs %s | cpu=%ss peakRss=%sMiB\n' \
        "$NAME" "$1" "$4" "$verdict" "$dur" "$fail" "$reqs" "$(awk "BEGIN { print $c1 - $c0 }")" "$(hwm_mib)" | tee -a "$OUT"
    return "$rc"
}

start_server "$@"
step 1000 60s 15s 0.1 >/dev/null || true   # warm-up, not scored

lo=0; hi=0; v=2000
while true; do
    if step "$v" 60s 30s 0.1; then lo=$v; v=$(( v * 3 / 2 )); else hi=$v; break; fi
    [ "$v" -gt 20000 ] && break
done
if [ "$hi" -gt 0 ]; then
    for _ in 1 2; do
        mid=$(( (lo + hi) / 2 ))
        if step "$mid" 60s 30s 0.1; then lo=$mid; else hi=$mid; fi
    done
fi
echo "RESULT $NAME: highest passing scaled VUs = $lo (~$(( lo * 10 )) users), first failing = $hi" | tee -a "$OUT"

# connection-heavy check with the real think time, on a fresh server
start_server "$@"
step 1000 60s 15s 1 >/dev/null || true
step 10000 2m 60s 1 || true

docker logs srv 2>&1 | grep -iE "exception|error|OutOfMemory" | head -5
docker rm -f srv >/dev/null 2>&1
{ echo "### $NAME"; echo '```'; cat "$OUT"; echo '```'; } >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
