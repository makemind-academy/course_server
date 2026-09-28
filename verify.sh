#!/bin/bash
# Each step is checked against what its article claims, not against "it ran".
set -uo pipefail
cd "$(dirname "$0")"

INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}'
NOTE='{"jsonrpc":"2.0","method":"notifications/initialized"}'

mkdir -p captures
: > captures/run.log
: > captures/stderr.log

# Send the handshake plus the given requests to a step, print what came back.
ask() {
  local step=$1; shift
  {
    # `dart run` compiles before main() starts; write nothing until it is up,
    # and hold stdin open afterwards so the server does not see EOF and exit
    # before it has answered.
    sleep 3
    printf '%s\n%s\n' "$INIT" "$NOTE"
    for r in "$@"; do sleep 0.4; printf '%s\n' "$r"; done
    sleep 2
  } | dart run "bin/$step.dart" 2>>captures/stderr.log
}

say() { echo "$1" | tee -a captures/run.log; }
die() { echo "   $1"; exit 1; }

echo "   [1/7] analyze"
dart pub get >/dev/null 2>&1
dart analyze | tail -1

echo "   [2/7] step1 — the server answers initialize"
ask step1 > captures/s1.txt
grep -q 'Course' captures/s1.txt || die "step1: no serverInfo"
say "step1  initialize -> serverInfo Course"

echo "   [3/7] step2 — one tool is listed"
ask step2 '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' > captures/s2.txt
grep -q 'desk.count' captures/s2.txt || die "step2: tool not listed"
say "step2  tools/list -> desk.count"

echo "   [4/7] step3 — bad input is refused, good input is not"
ask step3 \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"desk.admit","arguments":{"count":0}}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"desk.admit","arguments":{"count":99}}}' \
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"desk.admit","arguments":{"count":1}}}' \
  > captures/s3.txt
grep -q 'count must be 1 or more' captures/s3.txt || die "step3: zero was not refused"
grep -q 'only 3 waiting'          captures/s3.txt || die "step3: over-count was not refused"
grep -q 'waiting.*2'              captures/s3.txt || die "step3: a valid admit did not go through"
say "step3  refused 0 and 99, admitted 1 -> waiting 2"

echo "   [5/7] step4 — the screen is a document the server hands out"
ask step4 '{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"ui://desk"}}' > captures/s4.txt
grep -q 'ui://desk' captures/s4.txt || die "step4: resource not served"
grep -q 'page'      captures/s4.txt || die "step4: served document is not a screen"
# The claim is that the screen is not in the code.
grep -q 'fontSize' bin/step4.dart && die "step4: the screen is inside the code"
say "step4  ui://desk served from ui/desk.json ($(grep -c '' ui/desk.json) lines), not from the code"

echo "   [6/7] step5 — the count outlives the process"
rm -f desk-state.json
ask step5 '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"desk.admit","arguments":{"count":2}}}' >/dev/null
ask step5 '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"desk.state","arguments":{}}}' > captures/s5.txt
grep -q 'waiting.*1' captures/s5.txt || die "step5: the count did not survive a restart"
say "step5  admitted 2, process ended, a new process still reads waiting 1"

echo "   [7/7] step6 — the notification says only that it changed"
rm -f desk-state.json
# The server only sends resources/updated to clients that asked for it, so the
# probe subscribes first. Calling notifyResourceUpdated without a subscriber
# puts nothing on the wire — which is the point of the step.
ask step6 \
  '{"jsonrpc":"2.0","id":2,"method":"resources/subscribe","params":{"uri":"desk://waiting"}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"desk.admit","arguments":{"count":1}}}' \
  > captures/s6.txt
grep -q 'notified desk://waiting' captures/stderr.log || die "step6: nothing was notified"
grep -q 'resources/updated' captures/s6.txt || die "step6: no update notification on the wire"
python3 - <<'PY' || exit 1
import json, sys
lines = [l for l in open('captures/s6.txt') if 'resources/updated' in l]
if not lines:
    sys.exit(1)
params = json.loads(lines[0]).get('params', {})
extra = set(params) - {'uri'}
if extra:
    print('   step6: the notification carried', sorted(extra), '— it must carry only the uri')
    sys.exit(1)
print('   notification params:', json.dumps(params))
PY
say "step6  notification carried the uri and no value"

rm -f desk-state.json
say ""
say "6 steps · each checked against its own claim"
