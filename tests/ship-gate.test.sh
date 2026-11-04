#!/usr/bin/env bash
# End-to-end tests for ship-gate.sh in a throwaway git repo with a local bare
# remote. Usage: bash tests/ship-gate.test.sh
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$HERE/opencode/scripts/ship-gate.sh"
PASSES=0; FAILURES=0

pass() { echo "  PASS: $*"; PASSES=$((PASSES+1)); }
failc() { echo "  FAIL: $*"; FAILURES=$((FAILURES+1)); }

# expect <rc> <description> <command...>; prints the command's output.
expect() {
  local want="$1" desc="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  printf '%s\n' "$out" | sed 's/^/    | /'
  if [ "$rc" = "$want" ]; then pass "$desc (exit $rc)"; else failc "$desc (wanted exit $want, got $rc)"; fi
  LAST_OUT="$out"
}

contains() { case "$LAST_OUT" in *"$1"*) pass "output mentions: $1" ;; *) failc "output lacks: $1" ;; esac; }

section() { echo; echo "== $*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git init -q --bare -b main "$TMP/remote.git"
git clone -q "$TMP/remote.git" "$TMP/repo" 2>/dev/null
REPO="$TMP/repo"
cd "$REPO" || exit 1
git config user.email ship@test.invalid
git config user.name "ship test"
mkdir -p src tests
printf 'greet() { echo "hello $1"; }\n' > src/greet.sh
cat > tests/greet_test.sh <<'EOF'
. src/greet.sh
[ "$(greet ann)" = "hello ann" ] || { echo "named greeting broken"; exit 1; }
EOF
printf '.pipeline/\n' > .gitignore
echo "# demo" > README.md
git add -A && git commit -q -m init && git push -q -u origin main 2>/dev/null
git remote set-head origin -a >/dev/null

# start_run <request>; sets RUN and WT.
start_run() {
  local out; out="$("$GATE" init -- "$1")" || { echo "$out"; failc "init failed for: $1"; return 1; }
  RUN="$(printf '%s\n' "$out" | sed -n 's/^RUN=//p')"
  WT="$(printf '%s\n' "$out" | sed -n 's/^WT=//p')"
  printf 'src/greet.sh  # greeting logic\ntests/greet_test.sh  # regression test\n' > "$RUN/allowed-files.txt"
  printf 'required | unit | bash tests/greet_test.sh\nskip | lint | no linter configured in this repo\n' > "$RUN/checks.txt"
}

fix_empty_name() {
  printf 'greet() { echo "hello ${1:-world}"; }\n' > "$WT/src/greet.sh"
  printf '[ "$(greet)" = "hello world" ] || { echo "empty name broken"; exit 1; }\n' >> "$WT/tests/greet_test.sh"
}

approve() {
  "$GATE" scope "$RUN" review >/dev/null
  printf 'VERDICT: PASS\n\n## Reasoning\nMinimal and tested.\n' > "$RUN/review.md"
  "$GATE" review "$RUN" >/dev/null
}

echo "gate script: $GATE"
echo "throwaway repo: $REPO"

section "0. shared files have not drifted"
for copy in "$HERE/claude/scripts/ship-gate.sh" "$HERE/cursor/.cursor/scripts/ship-gate.sh"; do
  if cmp -s "$GATE" "$copy"; then pass "${copy#"$HERE"/} matches"; else failc "${copy#"$HERE"/} differs from opencode/scripts/ship-gate.sh"; fi
done
body() { awk 'BEGIN{c=0} c>=2{print; next} /^---$/{c++}' "$1"; }
for a in planner coder tester reviewer pr-writer; do
  if [ "$(body "$HERE/opencode/agent/$a.md")" = "$(body "$HERE/claude/agents/$a.md")" ]; then pass "$a agent text matches between opencode and claude"
  else failc "$a agent text differs between opencode/agent and claude/agents"; fi
done
for skill in pr-review writing-pr-descriptions; do
  for copy in "$HERE/claude/skills/$skill/SKILL.md" "$HERE/cursor/.cursor/skills/$skill/SKILL.md"; do
    if cmp -s "$HERE/opencode/skills/$skill/SKILL.md" "$copy"; then pass "${copy#"$HERE"/} matches opencode/skills/$skill"
    else failc "${copy#"$HERE"/} differs from opencode/skills/$skill/SKILL.md"; fi
  done
done
steps() { awk '/^## Sequence$/{p=1} p' "$1"; }
[ "$(steps "$HERE/opencode/agent/ship.md")" = "$(steps "$HERE/claude/commands/ship.md")" ] &&
  pass "orchestrator steps match between opencode and claude" || failc "orchestrator steps differ between opencode and claude"

section "1. clean pass: isolate, scope, verify, regress, review, publish"
expect 0 "init creates branch and worktree from origin/main" "$GATE" init -- "Default greeting for empty name"
RUN="$(printf '%s\n' "$LAST_OUT" | sed -n 's/^RUN=//p')"; WT="$(printf '%s\n' "$LAST_OUT" | sed -n 's/^WT=//p')"
printf 'src/greet.sh  # greeting logic\ntests/greet_test.sh  # regression test\n' > "$RUN/allowed-files.txt"
printf 'required | unit | bash tests/greet_test.sh\nskip | lint | no linter configured in this repo\n' > "$RUN/checks.txt"
fix_empty_name
expect 0 "scope after coding is within contract" "$GATE" scope "$RUN" code
expect 0 "verify runs required checks and records the skip" "$GATE" verify "$RUN"
contains "SKIP lint"
expect 0 "regression test fails against the recorded base" "$GATE" regress "$RUN" empty-name tests/greet_test.sh -- bash tests/greet_test.sh
approve
expect 0 "all publication gates pass" "$GATE" gate "$RUN"
printf 'Default greeting for empty name\n' > "$RUN/commit-msg.txt"
expect 0 "publish stages the explicit list, commits, and pushes" "$GATE" publish "$RUN" --no-pr
BASE_SHA="$(sed -n "s/^BASE_SHA='\(.*\)'/\1/p" "$RUN/run.env")"
BRANCH="$(sed -n "s/^BRANCH='\(.*\)'/\1/p" "$RUN/run.env")"
pushed="$(git -C "$TMP/remote.git" diff --no-renames --binary --full-index "$BASE_SHA" "$BRANCH" | (sha256sum 2>/dev/null || shasum -a 256) | cut -d' ' -f1)"
[ "$pushed" = "$(cat "$RUN/candidate.sha256")" ] && pass "pushed commit equals the reviewed candidate hash" || failc "pushed commit differs from candidate"
[ "$(git -C "$TMP/remote.git" diff --name-only "$BASE_SHA" "$BRANCH" | tr '\n' ' ')" = "src/greet.sh tests/greet_test.sh " ] &&
  pass "pushed commit touches only the two allowed files" || failc "pushed commit has unexpected files"
grep -q '"outcome": "published"' "$RUN/metrics.json" && pass "metrics.json records the run" || failc "metrics.json missing"
echo "    | $(cat "$RUN/metrics.json" | tr -d '\n' | tr -s ' ')"

section "2. out-of-scope file blocks publication"
start_run "Out of scope stray file"
fix_empty_name
echo "scratch" > "$WT/notes.txt"
expect 3 "scope flags the unlisted file" "$GATE" scope "$RUN" code
contains '`notes.txt` | doc | +1/-0 | NO'
"$GATE" verify "$RUN" >/dev/null; approve 2>/dev/null
expect 3 "gate refuses out-of-scope paths" "$GATE" gate "$RUN"
contains "out of scope: notes.txt"
expect 3 "publish refuses too" "$GATE" publish "$RUN" --no-pr
git -C "$TMP/remote.git" rev-parse --verify --quiet "refs/heads/$(sed -n "s/^BRANCH='\(.*\)'/\1/p" "$RUN/run.env")" >/dev/null &&
  failc "branch was pushed" || pass "nothing was pushed"

section "3. patch changed after review"
start_run "Patch changed after review"
fix_empty_name
"$GATE" verify "$RUN" >/dev/null; approve
printf 'greet() { echo "hi ${1:-world}"; }\n' > "$WT/src/greet.sh"
expect 3 "gate detects the post-review edit" "$GATE" gate "$RUN"
contains "candidate changed after checks ran"
contains "candidate changed after review"
"$GATE" scope "$RUN" review >/dev/null
printf 'greet() { echo "hey ${1:-world}"; }\n' > "$WT/src/greet.sh"
printf 'VERDICT: PASS\n' > "$RUN/review.md"
expect 3 "review refuses to record a verdict for a stale snapshot" "$GATE" review "$RUN"

section "4. non-PASS verdicts"
start_run "Reviewer returns fail verdict"
fix_empty_name
"$GATE" verify "$RUN" >/dev/null; "$GATE" scope "$RUN" review >/dev/null
printf 'VERDICT: FAIL\n\n## Blocking issues\n1. [coder][Correctness] example\n' > "$RUN/review.md"
expect 0 "review records FAIL" "$GATE" review "$RUN"
contains "VERDICT=FAIL"
expect 3 "gate refuses a FAIL verdict" "$GATE" gate "$RUN"
contains "review verdict is not PASS"
printf 'Verdict: pass, looks fine\n' > "$RUN/review.md"
expect 3 "review rejects a malformed verdict line" "$GATE" review "$RUN"

section "5. size threshold warns but does not block"
start_run "Add six greeting variants"
printf 'src/*.sh  # variants\ntests/greet_test.sh  # regression test\n' > "$RUN/allowed-files.txt"
for i in 1 2 3 4 5 6; do printf 'v%s() { echo %s; }\n' "$i" "$i" > "$WT/src/v$i.sh"; done
expect 0 "scope warns at 6 code files and still exits 0" "$GATE" scope "$RUN" code
contains "WARN size"
SHIP_WARN_CODE_FILES=10 "$GATE" scope "$RUN" code | grep -q "WARN size" && failc "threshold override ignored" || pass "SHIP_WARN_CODE_FILES=10 removes the warning"
"$GATE" verify "$RUN" >/dev/null; approve
expect 0 "gate passes with a size warning line" "$GATE" gate "$RUN"
contains "warn size over threshold"
printf 'Add greeting variants\n' > "$RUN/commit-msg.txt"
expect 0 "publish succeeds despite the warning" "$GATE" publish "$RUN" --no-pr
grep -q '"size_warnings": [1-9]' "$RUN/metrics.json" && pass "metrics count the size warning" || failc "size warning not in metrics"

section "6. dirty checkout stops init"
echo wip > "$REPO/wip.txt"
expect 2 "init refuses a dirty checkout" "$GATE" init -- "Anything at all"
rm -f "$REPO/wip.txt"

section "7. failing required check"
start_run "Required check fails"
printf 'greet() { echo "bye $1"; }\n' > "$WT/src/greet.sh"
expect 3 "verify fails" "$GATE" verify "$RUN"
approve 2>/dev/null
expect 3 "gate reports the failed check" "$GATE" gate "$RUN"
contains "required checks failed: unit"

section "8. checks that modify the candidate are rejected"
start_run "Checks write cache files"
fix_empty_name
printf 'required | unit | bash tests/greet_test.sh && echo cache > src/cache.txt\n' > "$RUN/checks.txt"
expect 3 "verify detects files created by checks" "$GATE" verify "$RUN"
contains "checks changed the candidate"

section "9. commits made by agents are rejected"
start_run "Agent commits on its own"
fix_empty_name
"$GATE" verify "$RUN" >/dev/null; approve
git -C "$WT" add -A && git -C "$WT" commit -q -m sneaky
expect 3 "gate refuses a worktree whose HEAD moved" "$GATE" gate "$RUN"
contains "worktree HEAD moved off base"

section "10. docs, config, and test data do not count toward the size warning"
start_run "Docs and config only change"
printf 'README.md  # docs\ndocs/*  # docs\nconfig/*  # config\npackage-lock.json  # lockfile\ntests/*  # fixtures\n' > "$RUN/allowed-files.txt"
mkdir -p "$WT/docs" "$WT/config"
seq 1 500 | sed 's/^/line /' >> "$WT/README.md"
for i in 1 2 3 4 5 6; do seq 1 100 > "$WT/docs/page$i.md"; done
seq 1 200 | sed 's/^/k$: v/' > "$WT/config/app.yaml"
printf '{"lockfileVersion": 3}\n' > "$WT/package-lock.json"
seq 1 450 | sed 's/^/{"n": /; s/$/}/' > "$WT/tests/data.json"
expect 0 "scope stays quiet with 9 docs/config files and 1300+ non-code lines" "$GATE" scope "$RUN" code
contains "Code: 0 files, 0 lines (counted toward the size warning)"
contains "Docs and config: 9 files, 1301 lines"
contains '`tests/data.json` | test | +450/-0 | yes'
contains '`config/app.yaml` | config | +200/-0 | yes'
case "$LAST_OUT" in *"WARN size"*) failc "docs/config triggered the size warning" ;; *) pass "no size warning for docs and config" ;; esac
"$GATE" metrics "$RUN" test >/dev/null
grep -q '"code_lines": 0' "$RUN/metrics.json" && grep -q '"doc_config_lines": 1301' "$RUN/metrics.json" &&
  pass "metrics separate code lines from docs/config lines" || failc "metrics do not separate code from docs/config"

section "11. code-line threshold: 350 lines is quiet, 401 lines warns"
start_run "Large single file change"
printf 'src/*  # code\n' > "$RUN/allowed-files.txt"
seq 1 350 | sed 's/^/echo /' > "$WT/src/big.sh"
expect 0 "350 code lines (under 400)" "$GATE" scope "$RUN" code
contains "Code: 1 files, 350 lines"
case "$LAST_OUT" in *"WARN size"*) failc "350 lines warned" ;; *) pass "no size warning at 350 code lines" ;; esac
seq 1 401 | sed 's/^/echo /' > "$WT/src/big.sh"
expect 0 "401 code lines warns but still exits 0" "$GATE" scope "$RUN" code
contains "WARN size: over 5 code files or 400 code lines"
SHIP_WARN_CODE_LINES=500 "$GATE" scope "$RUN" code | grep -q "WARN size" && failc "line override ignored" || pass "SHIP_WARN_CODE_LINES=500 removes the warning"

section "runs.tsv"
sed 's/^/    | /' "$REPO/.pipeline/runs.tsv"

echo
echo "RESULT: $PASSES passed, $FAILURES failed"
[ "$FAILURES" -eq 0 ]
