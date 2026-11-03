#!/usr/bin/env bash
# ship-gate.sh: deterministic isolation, scope, verification, and publication
# gates for the /ship pipeline. Identical copies live in opencode/scripts,
# claude/scripts, and cursor/.cursor/scripts; tests/ship-gate.test.sh checks
# that they match.
#
# Usage:
#   ship-gate.sh init [--base <branch>] [--repo <dir>] -- <request text>
#   ship-gate.sh scope   <run> <stage>
#   ship-gate.sh verify  <run>
#   ship-gate.sh regress <run> <name> <test-file>... -- <command>
#   ship-gate.sh review  <run>
#   ship-gate.sh event   <run> <name>
#   ship-gate.sh gate    <run>
#   ship-gate.sh publish <run> [--no-pr]
#   ship-gate.sh metrics <run> [outcome]
#
# Exit codes: 0 ok, 1 usage or internal error, 2 precondition failed
# (dirty checkout, unresolved base), 3 gate failed.
#
# Run-dir contract files written by agents:
#   allowed-files.txt  one path or glob per line; text after " #" is the reason
#   checks.txt         "<required|optional|skip> | <name> | <command or skip reason>"
#   review.md          first line exactly "VERDICT: PASS" or "VERDICT: FAIL"
#   pr-title.txt, pr-body.md, commit-msg.txt (commit-msg falls back to title)

set -u

# Tunables. Override with environment variables of the same name.
SHIP_WARN_PROD_FILES="${SHIP_WARN_PROD_FILES:-5}"
SHIP_WARN_PROD_LINES="${SHIP_WARN_PROD_LINES:-300}"
SHIP_TEST_REGEX="${SHIP_TEST_REGEX:-(^|/)(tests?|__tests__|specs?|testdata|fixtures)/|(^|/)test_[^/]*$|[._-](test|spec)s?\.[^/]+$}"
# Space-separated paths ignored by the dirty-checkout check, in addition to .pipeline.
SHIP_DIRTY_EXCLUDE="${SHIP_DIRTY_EXCLUDE:-}"

die()  { echo "ship-gate: $*" >&2; exit 1; }
fail() { echo "ship-gate: FAIL: $1" >&2; exit "${2:-3}"; }

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1; fi
}

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

load_run() {
  RUN="${1:-}"
  [ -n "$RUN" ] || die "missing run directory"
  RUN="$(cd "$RUN" 2>/dev/null && pwd)" || die "run directory not found: $1"
  [ -f "$RUN/run.env" ] || die "not a ship run (no run.env): $RUN"
  # shellcheck disable=SC1091
  . "$RUN/run.env"
  [ -d "$WT" ] || die "worktree missing: $WT"
}

dirty_status() {
  local root="$1" args=(":(exclude).pipeline")
  local p
  for p in $SHIP_DIRTY_EXCLUDE; do args+=(":(exclude)$p"); done
  git -C "$root" status --porcelain --untracked-files=normal -- . "${args[@]}"
}

# Candidate = everything in the worktree that differs from BASE_SHA,
# including new untracked files that are not gitignored. Built in a
# throwaway index so the agents' own index state never matters.
candidate_diff() {
  local idx; idx="$(mktemp)"
  rm -f "$idx"
  (
    export GIT_INDEX_FILE="$idx"
    git -C "$WT" read-tree "$BASE_SHA" &&
    git -C "$WT" add -A . &&
    git -C "$WT" -c core.quotepath=off diff --cached --no-renames --no-color --no-ext-diff "$@" "$BASE_SHA"
  )
  local rc=$?
  rm -f "$idx"
  return $rc
}

staged_diff() {
  git -C "$WT" -c core.quotepath=off diff --cached --no-renames --no-color --no-ext-diff "$@" "$BASE_SHA"
}

live_hash() { candidate_diff --binary --full-index | sha256; }

is_test() { [[ "$1" =~ $SHIP_TEST_REGEX ]]; }

allowed() {
  local f="$1" line pat
  [ -f "$RUN/allowed-files.txt" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    pat="${line%%[[:space:]]#*}"
    pat="$(trim "$pat")"
    case "$pat" in ''|'#'*) continue ;; esac
    # shellcheck disable=SC2053
    [[ "$f" == $pat ]] && return 0
  done < "$RUN/allowed-files.txt"
  return 1
}

# Writes candidate.patch, candidate.sha256, files.tsv, scope.md.
# Sets PROD_FILES PROD_LINES TEST_FILES TEST_LINES UNEXPECTED SIZE_WARN.
snapshot() {
  local stage="$1"
  candidate_diff --binary --full-index > "$RUN/candidate.patch" || die "could not build candidate diff"
  sha256 < "$RUN/candidate.patch" > "$RUN/candidate.sha256"
  HASH="$(cat "$RUN/candidate.sha256")"
  PROD_FILES=0; PROD_LINES=0; TEST_FILES=0; TEST_LINES=0; UNEXPECTED=0; SIZE_WARN=0
  : > "$RUN/files.tsv"
  local add del path kind ok lines rows=""
  while IFS="$(printf '\t')" read -r add del path; do
    [ -n "$path" ] || continue
    [ "$add" = "-" ] && add=0
    [ "$del" = "-" ] && del=0
    lines=$((add + del))
    if is_test "$path"; then kind="test"; TEST_FILES=$((TEST_FILES+1)); TEST_LINES=$((TEST_LINES+lines))
    else kind="prod"; PROD_FILES=$((PROD_FILES+1)); PROD_LINES=$((PROD_LINES+lines)); fi
    if allowed "$path"; then ok=yes; else ok=NO; UNEXPECTED=$((UNEXPECTED+1)); echo "$path" >> "$RUN/unexpected-seen.txt"; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$add" "$del" "$ok" "$path" >> "$RUN/files.tsv"
    rows="$rows| \`$path\` | $kind | +$add/-$del | $ok |
"
  done < <(candidate_diff --numstat)
  if [ "$PROD_FILES" -gt "$SHIP_WARN_PROD_FILES" ] || [ "$PROD_LINES" -gt "$SHIP_WARN_PROD_LINES" ]; then SIZE_WARN=1; fi
  {
    echo "# Scope ($stage)"
    echo
    echo "Candidate: \`$HASH\` against base \`$BASE_SHA\` ($PR_BASE)"
    echo
    echo "| File | Kind | Lines | Allowed |"
    echo "|---|---|---|---|"
    printf '%s' "$rows"
    echo
    echo "Production: $PROD_FILES files, $PROD_LINES lines. Tests: $TEST_FILES files, $TEST_LINES lines."
    [ "$SIZE_WARN" = 1 ] && echo "WARN size: over $SHIP_WARN_PROD_FILES production files or $SHIP_WARN_PROD_LINES production lines. Needs a Size explanation in changes.md and a scope check in review."
    [ "$UNEXPECTED" -gt 0 ] && echo "FAIL scope: $UNEXPECTED file(s) not in allowed-files.txt."
  } > "$RUN/scope.md"
}

cmd_init() {
  local base="" repo="."
  while [ $# -gt 0 ]; do
    case "$1" in
      --base) base="${2:-}"; shift 2 ;;
      --repo) repo="${2:-}"; shift 2 ;;
      --) shift; break ;;
      *) break ;;
    esac
  done
  local request="$*"
  [ -n "$(trim "$request")" ] || die "init needs the request text"
  local root; root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" || fail "not a git repository: $repo" 2

  local dirty; dirty="$(dirty_status "$root")"
  [ -z "$dirty" ] || { echo "$dirty" >&2; fail "checkout has uncommitted changes; commit or stash them yourself, then rerun" 2; }

  local has_origin=0
  git -C "$root" remote get-url origin >/dev/null 2>&1 && has_origin=1
  if [ -z "$base" ]; then
    base="$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
    [ -n "$base" ] || base="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)"
    [ -n "$base" ] || base=main
  fi
  local base_sha=""
  if [ "$has_origin" = 1 ]; then
    git -C "$root" fetch --quiet origin "$base" 2>/dev/null &&
      base_sha="$(git -C "$root" rev-parse --verify --quiet "refs/remotes/origin/$base^{commit}")"
  fi
  if [ -z "$base_sha" ]; then
    base_sha="$(git -C "$root" rev-parse --verify --quiet "refs/heads/$base^{commit}")" ||
      fail "cannot resolve base branch '$base' on origin or locally" 2
    echo "ship-gate: WARN base '$base' resolved from the local branch, not origin; the PR base must exist on origin to publish" >&2
  fi

  local slug; slug="$(printf '%s' "$request" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' ' ' |
    awk '{for(i=1;i<=NF&&i<=6;i++) printf "%s%s", (i>1?"-":""), $i}')"
  [ -n "$slug" ] || slug=change
  local run; run="$root/.pipeline/$(date +%Y-%m-%d)-$slug"

  if [ -f "$run/run.env" ]; then
    local old_wt old_branch old_base
    old_wt="$(sed -n 's/^WT=//p' "$run/run.env" | tr -d "'")"
    old_branch="$(sed -n 's/^BRANCH=//p' "$run/run.env" | tr -d "'")"
    old_base="$(sed -n 's/^BASE_SHA=//p' "$run/run.env" | tr -d "'")"
    [ -n "$old_wt" ] && git -C "$root" worktree remove --force "$old_wt" 2>/dev/null
    if [ -n "$old_branch" ] && [ "$(git -C "$root" rev-parse --verify --quiet "refs/heads/$old_branch")" = "$old_base" ] &&
       ! git -C "$root" rev-parse --verify --quiet "refs/remotes/origin/$old_branch" >/dev/null; then
      git -C "$root" branch -q -D "$old_branch"
    fi
  fi
  rm -rf "$run"
  git -C "$root" worktree prune
  mkdir -p "$run"

  local branch="ship/$slug" n=2
  while git -C "$root" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null ||
        { [ "$has_origin" = 1 ] && git -C "$root" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; }; do
    branch="ship/$slug-$n"; n=$((n+1))
  done

  local wt="$run/worktree"
  git -C "$root" worktree add --quiet -b "$branch" "$wt" "$base_sha" || fail "could not create worktree" 2
  [ -z "$(git -C "$wt" status --porcelain)" ] || fail "new worktree is not clean" 2

  git -C "$root" check-ignore -q .pipeline/x 2>/dev/null ||
    echo "ship-gate: WARN .pipeline/ is not gitignored in $root; add it so run folders stay out of searches and status" >&2

  {
    printf "ROOT='%s'\nRUN_DIR='%s'\nWT='%s'\nBRANCH='%s'\nPR_BASE='%s'\nBASE_SHA='%s'\nSTART_EPOCH='%s'\n" \
      "$root" "$run" "$wt" "$branch" "$base" "$base_sha" "$(date +%s)"
  } > "$run/run.env"
  printf '%s\n' "$request" > "$run/request.md"
  echo "$(date +%s) init" > "$run/events.log"
  printf 'RUN=%s\nWT=%s\nBRANCH=%s\nPR_BASE=%s\nBASE_SHA=%s\n' "$run" "$wt" "$branch" "$base" "$base_sha"
}

cmd_scope() {
  load_run "${1:-}"; local stage="${2:-adhoc}"
  snapshot "$stage"
  echo "$(date +%s) scope:$stage" >> "$RUN/events.log"
  [ "$SIZE_WARN" = 1 ] && echo "$(date +%s) size-warn" >> "$RUN/events.log"
  cat "$RUN/scope.md"
  local main_dirty; main_dirty="$(dirty_status "$ROOT")"
  [ -z "$main_dirty" ] || echo "WARN main checkout $ROOT changed since init; edits there are not part of the candidate:
$main_dirty"
  [ "$UNEXPECTED" -eq 0 ] || exit 3
}

cmd_verify() {
  load_run "${1:-}"
  [ -f "$RUN/checks.txt" ] || fail "no checks.txt in $RUN"
  snapshot verify >/dev/null
  local h0="$HASH" line kind rest name cmd rc any_fail=0 n_req=0 n_skip=0
  mkdir -p "$RUN/checks"
  local out="$RUN/checks.tsv.tmp"
  : > "$out"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$(trim "$line")" in ''|'#'*) continue ;; esac
    kind="$(trim "${line%%|*}")"; rest="${line#*|}"
    name="$(trim "${rest%%|*}")"; cmd="$(trim "${rest#*|}")"
    [ -n "$name" ] && [ "$rest" != "$line" ] || fail "malformed checks.txt line: $line" 1
    case "$kind" in
      skip) n_skip=$((n_skip+1)); printf '%s\t%s\t%s\t%s\n' "$name" skip - "$cmd" >> "$out"; echo "SKIP $name: $cmd"; continue ;;
      required) n_req=$((n_req+1)) ;;
      optional) ;;
      *) fail "unknown check kind '$kind' in: $line" 1 ;;
    esac
    (cd "$WT" && bash -c "$cmd") > "$RUN/checks/$name.log" 2>&1
    rc=$?
    printf '%s\t%s\t%s\t%s\n' "$name" "$kind" "$rc" "$cmd" >> "$out"
    if [ "$rc" -eq 0 ]; then echo "PASS $name ($kind)"
    else echo "FAIL $name ($kind, exit $rc) log: $RUN/checks/$name.log"; [ "$kind" = required ] && any_fail=1; fi
  done < "$RUN/checks.txt"
  local h1; h1="$(live_hash)"
  if [ "$h1" != "$h0" ]; then
    rm -f "$out" "$RUN/checks.tsv"
    fail "checks changed the candidate (generated or cache files?). Gitignore or remove them, then rerun verify"
  fi
  { echo "candidate	$h0"; cat "$out"; } > "$RUN/checks.tsv"
  rm -f "$out"
  echo "$(date +%s) verify" >> "$RUN/events.log"
  [ "$n_req" -gt 0 ] || [ "$n_skip" -gt 0 ] || fail "checks.txt has no required checks and no explicit skips"
  [ "$any_fail" -eq 0 ] || exit 3
}

cmd_regress() {
  load_run "${1:-}"; local name="${2:-}"; shift 2 || die "usage: regress <run> <name> <file>... -- <command>"
  local files=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do files+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  [ ${#files[@]} -gt 0 ] && [ $# -gt 0 ] || die "usage: regress <run> <name> <file>... -- <command>"
  local tmp; tmp="$(mktemp -d)"
  git -C "$ROOT" worktree add --quiet --detach "$tmp/base" "$BASE_SHA" || die "could not create base worktree"
  local f
  for f in "${files[@]}"; do mkdir -p "$tmp/base/$(dirname "$f")"; cp "$WT/$f" "$tmp/base/$f" || die "missing $f"; done
  mkdir -p "$RUN/checks"
  (cd "$tmp/base" && bash -c "$*") > "$RUN/checks/regress-$name.log" 2>&1
  local rc=$?
  git -C "$ROOT" worktree remove --force "$tmp/base"; rm -rf "$tmp"
  printf '%s\t%s\t%s\n' "$name" "$rc" "$*" >> "$RUN/regress.tsv"
  if [ "$rc" -ne 0 ]; then echo "OK $name fails against base (exit $rc), as a regression test should"
  else echo "WARN $name passes against base; it does not demonstrate the bug"; exit 3; fi
}

cmd_review() {
  load_run "${1:-}"
  [ -f "$RUN/review.md" ] || fail "no review.md"
  [ -f "$RUN/candidate.sha256" ] || fail "no candidate snapshot; run scope before review"
  local first; first="$(grep -m1 -v '^[[:space:]]*$' "$RUN/review.md" | tr -d '\r')"
  local verdict
  case "$first" in
    "VERDICT: PASS") verdict=PASS ;;
    "VERDICT: FAIL") verdict=FAIL ;;
    *) fail "review.md must start with 'VERDICT: PASS' or 'VERDICT: FAIL', got: $first" ;;
  esac
  local seen; seen="$(cat "$RUN/candidate.sha256")"
  [ "$(live_hash)" = "$seen" ] || fail "candidate changed after the snapshot the reviewer read; rerun scope and review"
  printf 'verdict\t%s\ncandidate\t%s\n' "$verdict" "$seen" > "$RUN/review.tsv"
  echo "$(date +%s) review:$verdict" >> "$RUN/events.log"
  echo "VERDICT=$verdict"
}

cmd_event() {
  load_run "${1:-}"; [ -n "${2:-}" ] || die "usage: event <run> <name>"
  echo "$(date +%s) $2" >> "$RUN/events.log"
}

# Prints one line per gate; returns 3 if any fail.
run_gates() {
  local bad=0 h
  ok()  { echo "ok   $*"; }
  bad() { echo "FAIL $*"; bad=1; }

  [ "$(git -C "$WT" rev-parse HEAD)" = "$BASE_SHA" ] && ok "no commits made outside publish" ||
    bad "worktree HEAD moved off base $BASE_SHA; agents must not commit"
  snapshot gate >/dev/null
  h="$HASH"
  [ -s "$RUN/candidate.patch" ] && ok "candidate is non-empty ($h)" || bad "candidate patch is empty"

  [ "$UNEXPECTED" -eq 0 ] && ok "all changed paths are in allowed-files.txt" ||
    bad "out of scope: $(awk -F'\t' '$4=="NO"{printf "%s ", $5}' "$RUN/files.tsv")"
  [ "$SIZE_WARN" = 1 ] && echo "warn size over threshold ($PROD_FILES prod files, $PROD_LINES prod lines); review must have accepted the explanation"

  if [ ! -f "$RUN/checks.tsv" ]; then bad "checks never ran (no checks.tsv)"
  else
    [ "$(sed -n 's/^candidate	//p' "$RUN/checks.tsv")" = "$h" ] && ok "checks ran on this exact candidate" ||
      bad "candidate changed after checks ran"
    local failed nreq nskip
    failed="$(awk -F'\t' 'NR>1 && $2=="required" && $3!="0"{printf "%s ", $1}' "$RUN/checks.tsv")"
    nreq="$(awk -F'\t' 'NR>1 && $2=="required"' "$RUN/checks.tsv" | wc -l | tr -d ' ')"
    nskip="$(awk -F'\t' 'NR>1 && $2=="skip"' "$RUN/checks.tsv" | wc -l | tr -d ' ')"
    [ -z "$failed" ] && ok "required checks passed ($nreq required, $nskip skipped)" || bad "required checks failed: $failed"
    [ "$nreq" -gt 0 ] || [ "$nskip" -gt 0 ] || bad "no required checks and no explicit skips"
    awk -F'\t' 'NR>1 && $2=="skip"{print "     skipped " $1 ": " $4}' "$RUN/checks.tsv"
  fi

  if [ ! -f "$RUN/review.tsv" ]; then bad "no recorded review (run review)"
  else
    [ "$(sed -n 's/^verdict	//p' "$RUN/review.tsv")" = PASS ] && ok "review verdict is PASS" || bad "review verdict is not PASS"
    [ "$(sed -n 's/^candidate	//p' "$RUN/review.tsv")" = "$h" ] && ok "review covered this exact candidate" ||
      bad "candidate changed after review"
  fi
  return $((bad * 3))
}

cmd_gate() { load_run "${1:-}"; run_gates; }

cmd_publish() {
  load_run "${1:-}"; local no_pr=0
  [ "${2:-}" = "--no-pr" ] && no_pr=1
  run_gates || { cmd_metrics "$RUN" gate-failed >/dev/null; fail "publication gates failed"; }
  local h; h="$(cat "$RUN/candidate.sha256")"
  local title body msg
  title="$RUN/pr-title.txt"; body="$RUN/pr-body.md"; msg="$RUN/commit-msg.txt"
  [ -s "$msg" ] || msg="$title"
  [ -s "$msg" ] || fail "no commit-msg.txt or pr-title.txt"
  if [ "$no_pr" = 0 ]; then [ -s "$title" ] && [ -s "$body" ] || fail "pr-title.txt and pr-body.md are required"; fi

  local files=() f
  while IFS="$(printf '\t')" read -r _ _ _ _ f; do files+=("$f"); done < "$RUN/files.tsv"
  git -C "$WT" reset -q
  GIT_LITERAL_PATHSPECS=1 git -C "$WT" add -A -- "${files[@]}" || fail "staging failed"
  [ "$(staged_diff --binary --full-index | sha256)" = "$h" ] || fail "staged patch differs from the reviewed candidate"
  git -C "$WT" diff --quiet && [ -z "$(git -C "$WT" ls-files --others --exclude-standard)" ] ||
    fail "unstaged or untracked changes remain after staging"
  echo "ok   staged patch matches reviewed candidate ($h)"

  git -C "$WT" commit -q -F "$msg" || fail "commit failed (a hook may have rejected it)"
  local sha; sha="$(git -C "$WT" rev-parse HEAD)"
  [ "$(git -C "$WT" -c core.quotepath=off diff --no-renames --no-color --no-ext-diff --binary --full-index "$BASE_SHA" HEAD | sha256)" = "$h" ] ||
    fail "committed tree differs from the reviewed candidate (did a commit hook rewrite files?). Commit $sha is local only"
  echo "ok   commit $sha matches reviewed candidate"
  echo "$(date +%s) commit" >> "$RUN/events.log"

  local url=""
  if git -C "$WT" remote get-url origin >/dev/null 2>&1; then
    git -C "$WT" ls-remote --exit-code --heads origin "$PR_BASE" >/dev/null 2>&1 || fail "PR base '$PR_BASE' does not exist on origin; push it first"
    git -C "$WT" push -q -u origin "$BRANCH" || fail "push failed"
    echo "ok   pushed $BRANCH"
    if [ "$no_pr" = 0 ]; then
      url="$(cd "$WT" && gh pr create --draft --base "$PR_BASE" --head "$BRANCH" --title "$(cat "$title")" --body-file "$body")" ||
        fail "gh pr create failed; branch $BRANCH is pushed"
      echo "ok   opened draft PR $url"
    fi
  else
    [ "$no_pr" = 1 ] || fail "no origin remote; cannot push or open a PR"
  fi
  {
    echo "## SUCCESS"
    echo "- Branch: \`$BRANCH\` (base \`$PR_BASE\` at \`$BASE_SHA\`)"
    echo "- Commit: \`$sha\`"
    echo "- Candidate: \`$h\`"
    [ -n "$url" ] && echo "- Draft PR: $url"
  } > "$RUN/pr.md"
  cmd_metrics "$RUN" published >/dev/null
  git -C "$ROOT" worktree remove "$WT" 2>/dev/null && echo "ok   removed worktree $WT"
  cat "$RUN/pr.md"
}

cmd_metrics() {
  load_run "${1:-}"; local outcome="${2:-unknown}"
  [ -f "$RUN/files.tsv" ] || : > "$RUN/files.tsv"
  local pf pl tf tl unexp_final unexp_seen retries warns verdict runtime
  pf="$(awk -F'\t' '$1=="prod"' "$RUN/files.tsv" | wc -l | tr -d ' ')"
  pl="$(awk -F'\t' '$1=="prod"{s+=$2+$3} END{print s+0}' "$RUN/files.tsv")"
  tf="$(awk -F'\t' '$1=="test"' "$RUN/files.tsv" | wc -l | tr -d ' ')"
  tl="$(awk -F'\t' '$1=="test"{s+=$2+$3} END{print s+0}' "$RUN/files.tsv")"
  unexp_final="$(awk -F'\t' '$4=="NO"' "$RUN/files.tsv" | wc -l | tr -d ' ')"
  unexp_seen="$( [ -f "$RUN/unexpected-seen.txt" ] && sort -u "$RUN/unexpected-seen.txt" | wc -l | tr -d ' ' || echo 0)"
  retries="$(grep -c ' repair$' "$RUN/events.log" 2>/dev/null)"; retries="${retries:-0}"
  warns="$(grep -c ' size-warn$' "$RUN/events.log" 2>/dev/null)"; warns="${warns:-0}"
  verdict="$(sed -n 's/^verdict	//p' "$RUN/review.tsv" 2>/dev/null)"; verdict="${verdict:-none}"
  runtime=$(( $(date +%s) - START_EPOCH ))
  cat > "$RUN/metrics.json" <<EOF
{
  "run": "$(basename "$RUN")",
  "outcome": "$outcome",
  "verdict": "$verdict",
  "runtime_seconds": $runtime,
  "retries": $retries,
  "prod_files": $pf,
  "prod_lines": $pl,
  "test_files": $tf,
  "test_lines": $tl,
  "unexpected_files_final": $unexp_final,
  "unexpected_files_seen": $unexp_seen,
  "size_warnings": $warns
}
EOF
  local log="$ROOT/.pipeline/runs.tsv"
  [ -f "$log" ] || printf 'date\trun\toutcome\tverdict\truntime_s\tretries\tprod_files\tprod_lines\ttest_files\ttest_lines\tunexpected_seen\tsize_warnings\n' > "$log"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$(basename "$RUN")" "$outcome" "$verdict" \
    "$runtime" "$retries" "$pf" "$pl" "$tf" "$tl" "$unexp_seen" "$warns" >> "$log"
  cat "$RUN/metrics.json"
}

sub="${1:-}"; [ $# -gt 0 ] && shift
case "$sub" in
  init) cmd_init "$@" ;;
  scope) cmd_scope "$@" ;;
  verify) cmd_verify "$@" ;;
  regress) cmd_regress "$@" ;;
  review) cmd_review "$@" ;;
  event) cmd_event "$@" ;;
  gate) cmd_gate "$@" ;;
  publish) cmd_publish "$@" ;;
  metrics) cmd_metrics "$@" ;;
  *) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; [ -z "$sub" ] || exit 1 ;;
esac
