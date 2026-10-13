#!/bin/sh
# skill_scan.sh -- argument parsing and audit-target discovery for
# authoring:skill-check. It decides WHAT to audit and WHERE an issue would go;
# it never judges a check (that stays with skill_check.sh and the auditor).
#
# Usage:
#   skill_scan.sh args [skill-check arguments...]
#       Validate the arguments (references/help.md) and print one line:
#       mode<TAB>target<TAB>issue<TAB>yes<TAB>deep
#       mode single|dir|repo|recursive; issue on|off; yes and deep 0|1.
#   skill_scan.sh resolve <path | plugin:skill | skill>
#       Print the SKILL.md a single-mode argument names (references/batch-mode.md
#       "Skill-name resolution"). Ambiguous or not found: exit 2.
#   skill_scan.sh scan <mode> <target> [--snapshot] [--tmp <dir>]
#       Print the audit list, one TSV row per skill:
#       repo_dir  skill_md  target_host  target_repo  target_source  snapshot_ref
#       target_source upstream|origin|fork-parent|none. snapshot_ref is
#       <remote>/<branch>@<sha>[ stale:<date>] (--snapshot), clone@<sha> (repo
#       mode) or worktree. A status row has skill_md "-", target_source dup or
#       skip, and the reason in snapshot_ref. repo mode and --snapshot need
#       --tmp: a directory the caller made with mktemp and deletes afterwards.
#       repo mode with --snapshot clones a fork's parent, the issue target;
#       without it no networked gh call is made and target_source is origin.
#   skill_scan.sh parse-url <git-url>    print host<TAB>owner/repo
#   skill_scan.sh key <SKILL.md>         print the dedup key <plugin>:<skill>
#
# exit: 0 ok | 2 usage, bad argument, unresolvable skill | 3 git failure
# Network: `git fetch`/`git clone` and `gh repo view` against the audited
# repos' own remotes. Set SKILL_CHECK_GH to substitute the gh binary and
# SKILL_CHECK_SSH_CONFIG to read an ssh config file instead of ~/.ssh/config
# (tests). parse_url asks gh only for a local token (`gh auth token`).
#
# shortcut: paths with spaces or tabs break the TSV rows and the word-split
# loops below; marketplace repos use kebab-case paths. Switch to NUL-delimited
# output if that ever changes.

set -eu

GH=${SKILL_CHECK_GH:-gh}
tab=$(printf '\t')
# Fail a fetch/clone that needs credentials instead of hanging an unattended (-y) run on a prompt.
export GIT_TERMINAL_PROMPT=0

die() { printf 'skill-check: %s\n' "$1" >&2; exit "${2:-2}"; }

# abspath <path> -- physical absolute path of an existing file or directory.
abspath() {
  if [ -d "$1" ]; then (cd -P "$1" && pwd -P)
  else printf '%s/%s\n' "$(cd -P "$(dirname "$1")" && pwd -P)" "$(basename "$1")"
  fi
}

# parse_url <url> -- host<TAB>owner/repo for git@host:o/r, ssh://[user@]host[:port]/o/r
# and http(s)://[user@]host/o/r, each with an optional .git suffix.
parse_url() {
  case $1 in
    git@*:*) r=${1#git@}; h=${r%%:*}; p=${r#*:} ;;
    ssh://*) r=${1#ssh://}; r=${r#*@}; h=${r%%/*}; h=${h%%:*}; p=${r#*/} ;;
    http://*|https://*) r=${1#*://}; r=${r#*@}; h=${r%%/*}; p=${r#*/} ;;
    *) return 1 ;;
  esac
  p=${p%/}; p=${p%.git}
  # A leading - would reach ssh/gh as an option.
  case $h in ''|*/*|-*) return 1 ;; esac
  # An ssh host alias (git@github.com-work:o/r) names a Host block, not a
  # server gh knows: resolve it to its HostName. A host gh already knows stays
  # as is -- its HostName may be a transport detour (ssh.github.com:443), not
  # the API host (issue #91). Env tokens are blanked: gh hands them out for any
  # host name, so they would make every alias look logged in. github.com is
  # kept even when gh is not logged in to it, where the token check would fail.
  case $1 in
    http://*|https://*) ;;
    *) if [ "$h" != github.com ] && ! GH_TOKEN='' GITHUB_TOKEN='' GH_ENTERPRISE_TOKEN='' GITHUB_ENTERPRISE_TOKEN='' \
           "$GH" auth token --hostname "$h" >/dev/null 2>&1; then
         a=$(ssh ${SKILL_CHECK_SSH_CONFIG:+-F "$SKILL_CHECK_SSH_CONFIG"} -G "$h" 2>/dev/null |
           awk '$1 == "hostname" { print $2; exit }') || a=
         [ -z "$a" ] || h=$a
       fi ;;
  esac
  case $p in */*/*|/*|*/) return 1 ;; ?*/?*) ;; *) return 1 ;; esac
  printf '%s\t%s\n' "$h" "$p"
}

# plugin_name <repo-dir> -- "name" from .claude-plugin/plugin.json, or empty.
plugin_name() {
  [ -f "$1/.claude-plugin/plugin.json" ] || return 0
  grep -m1 '"name"' "$1/.claude-plugin/plugin.json" |
    sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/'
}

# key <SKILL.md> -- same resolution as Check 11's allowlist key: walk up for
# .claude-plugin/plugin.json (stop at .git or /), <plugin>:<name>, bare <name>
# when no manifest is found.
key() {
  d=$(cd "$(dirname "$1")" && pwd)
  name=$(awk -F': *' '/^name:/ { print $2; exit }' "$1" | tr -d '"' | tr ':' '-')
  [ -n "$name" ] || name=$(basename "$d")
  while :; do
    if [ -f "$d/.claude-plugin/plugin.json" ]; then
      printf '%s:%s\n' "$(plugin_name "$d")" "$name"; return
    fi
    if [ -e "$d/.git" ] || [ "$d" = / ]; then break; fi
    d=$(dirname "$d")
  done
  printf '%s\n' "$name"
}

# ---------- args ----------
args() {
  mode=; target=; issue=; yes=0; deep=0
  migrate='--recursive now walks repos under a directory; for the Check 13 Sub-skill Model Plan depth use --deep-subskills'
  set_mode() {
    [ -z "$mode" ] || die "give only one of <path|skill-name>, -d, -r, -R"
    mode=$1; target=$2
  }
  set_issue() {
    [ -z "$issue" ] || [ "$issue" = "$1" ] || die "--issue and --no-issue are mutually exclusive"
    issue=$1
  }
  while [ $# -gt 0 ]; do
    case $1 in
      -d|--dir|-r|--repo)
        if [ $# -lt 2 ]; then die "$1 needs a value"; fi
        case $2 in -*|'') die "$1 needs a value" ;; esac
        case $1 in
          -d|--dir) [ -d "$2" ] || die "$1: not a directory: $2"; set_mode dir "$2" ;;
          *) parse_url "$2" >/dev/null || die "$1: not a git URL (git@host:o/r, ssh://host/o/r, https://host/o/r): $2"
             set_mode repo "$2" ;;
        esac
        shift 2 ;;
      -R|--recursive)
        # No value, or a SKILL.md / skill dir where a root dir belongs, is the pre-rename
        # `<path> --recursive` form -- say so instead of a bare usage error.
        if [ $# -lt 2 ]; then die "$migrate"; fi
        case $2 in -*|'') die "$migrate" ;; esac
        if [ -f "$2" ] || [ -f "$2/SKILL.md" ]; then die "$migrate"; fi
        [ -d "$2" ] || die "$1: not a directory: $2"
        set_mode recursive "$2"; shift 2 ;;
      --issue) set_issue on; shift ;;
      --no-issue) set_issue off; shift ;;
      -y|--yes) yes=1; shift ;;
      --deep-subskills) deep=1; shift ;;
      -*) die "unknown option: $1 (see /authoring:skill-check help)" ;;
      *) set_mode single "$1"; shift ;;
    esac
  done
  [ -n "$mode" ] || mode=single
  if [ -z "$issue" ]; then
    if [ "$mode" = single ]; then issue=off; else issue=on; fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$mode" "$target" "$issue" "$yes" "$deep"
}

# child_repos <dir> -- git repos directly under <dir>, main checkouts (.git
# directory) before linked worktrees (.git file), so `x/` wins over
# `x-claude-1/` when both hold the same repo.
child_repos() {
  for c in "$1"/*/; do [ -d "$c.git" ] && abspath "$c"; done
  for c in "$1"/*/; do [ -f "$c.git" ] && abspath "$c"; done
  return 0
}

# ---------- resolve ----------
# pick <label> -- read "<plugin><TAB><SKILL.md>" candidates on stdin; print
# the first SKILL.md when every candidate is the same plugin (several
# checkouts of one repo), exit 2 listing them when the plugins differ.
pick() {
  c=$(awk -F'\t' '!seen[$1]++')
  [ -n "$c" ] || return 1
  if [ "$(printf '%s\n' "$c" | wc -l | tr -d ' ')" -gt 1 ]; then
    printf 'skill-check: "%s" is ambiguous -- name one of:\n' "$1" >&2
    printf '%s\n' "$c" | awk -F'\t' '{ printf "  %s:%s  (%s)\n", $1, s, $2 }' s="$skill" >&2
    exit 2
  fi
  printf '%s\n' "$c" | head -n1 | cut -f2
}

# installed_paths -- "<plugin><TAB><installPath>" from every installed_plugins.json.
installed_paths() {
  for j in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" \
           "$HOME"/.claude*/plugins/installed_plugins.json; do
    [ -f "$j" ] || continue
    awk '
      /^ *"[^"]+@[^"]+": *\[/ { n = $0; sub(/^ *"/, "", n); sub(/@.*/, "", n); next }
      /"installPath"/ { p = $0; sub(/.*"installPath": *"/, "", p); sub(/".*/, "", p); print n "\t" p }
    ' "$j"
  done
}

# hit <rc> -- after a pick: 0 prints $found, 1 (no candidate) falls through
# to the next resolution step, anything else (ambiguous) exits with it.
hit() {
  case $1 in
    0) printf '%s\n' "$found" ;;
    1) return 1 ;;
    *) exit "$1" ;;
  esac
}

resolve() {
  arg=$1
  if [ -f "$arg" ]; then abspath "$arg"; return; fi
  if [ -d "$arg" ]; then
    [ -f "$arg/SKILL.md" ] || die "no SKILL.md in $arg"
    abspath "$arg/SKILL.md"; return
  fi
  a=${arg#/}
  case $a in
    *[!A-Za-z0-9._:-]*|:*|*:|*:*:*|'') die "no such file or skill: $arg" ;;
  esac
  case $a in *:*) plugin=${a%%:*}; skill=${a#*:} ;; *) plugin=; skill=$a ;; esac

  # 2. local checkouts: the cwd's git toplevel, then each git repo directly under cwd.
  repos="$(git rev-parse --show-toplevel 2>/dev/null || true)
$(child_repos .)"
  rc=0; found=$(for r in $repos; do
    f=$r/skills/$skill/SKILL.md
    [ -f "$f" ] || continue
    p=$(plugin_name "$r")
    [ -z "$plugin" ] || [ "$p" = "$plugin" ] || continue
    # No manifest: the origin URL identifies the repo, so two checkouts of it
    # still count as one candidate.
    [ -n "$p" ] || p=$(git -C "$r" remote get-url origin 2>/dev/null) || p=$(basename "$r")
    printf '%s\t%s\n' "$p" "$f"
  done | pick "$a") || rc=$?
  hit $rc && return

  # 3. installed plugins (may be an older copy than a local checkout).
  rc=0; found=$(installed_paths | while IFS="$tab" read -r p ip; do
    [ -z "$plugin" ] || [ "$p" = "$plugin" ] || continue
    [ ! -f "$ip/skills/$skill/SKILL.md" ] || printf '%s\t%s\n' "$p" "$ip/skills/$skill/SKILL.md"
  done | pick "$a") || rc=$?
  hit $rc && return

  # 4. flat skill links, bare names only (they carry no plugin namespace).
  if [ -z "$plugin" ]; then
    rc=0; found=$(for f in "$HOME"/.claude*/skills/"$skill"/SKILL.md; do
      [ -f "$f" ] || continue
      printf '%s\t%s\n' "$(abspath "$f")" "$f"
    done | pick "$a") || rc=$?
    hit $rc && return
  fi
  die "no such file or skill: $arg"
}

# ---------- scan ----------
# discover <dir> -- every SKILL.md up to depth 4, prune list from
# references/batch-mode.md, de-duplicated by physical path.
discover() {
  find -L "$1" -mindepth 1 -maxdepth 4 \
    \( -name .git -o -name node_modules -o -name .claude -o -name .worktrees \
       -o -name tests -o -name fixtures -o -name vendor \) -prune \
    -o -name SKILL.md -type f -print 2>/dev/null |
    while IFS= read -r f; do abspath "$f"; done | sort -u
}

# target <repo-dir> -- host<TAB>owner/repo<TAB>remote: upstream first, then
# origin; a remote whose URL does not parse cannot take an issue.
target() {
  for r in upstream origin; do
    u=$(git -C "$1" remote get-url "$r" 2>/dev/null) || continue
    t=$(parse_url "$u") || continue
    printf '%s\t%s\n' "$t" "$r"; return
  done
  printf -- '-\t-\tnone\n'
}

# snapshot <repo-dir> <remote> <host> <owner/repo> <dest> -- extract the
# remote's default branch into <dest>; print its snapshot_ref. Returns 1 when
# no ref exists to snapshot.
snapshot() {
  stale=
  git -C "$1" fetch --quiet "$2" 2>/dev/null || stale=1
  # Default branch: the remote-tracking HEAD (absent after a plain
  # `remote add` + fetch), then the server's HEAD symref, then gh.
  b=$(git -C "$1" symbolic-ref --short "refs/remotes/$2/HEAD" 2>/dev/null) ||
    b=$2/$(git -C "$1" ls-remote --symref "$2" HEAD 2>/dev/null |
      awk '$1 == "ref:" { sub("refs/heads/", "", $2); print $2; exit }') ||
    b=
  case $b in ''|*/) b=$2/$(GH_HOST=$3 "$GH" repo view "$4" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null) || return 1 ;; esac
  sha=$(git -C "$1" rev-parse --verify -q "$b^{commit}") || return 1
  # Through a private index rather than `git archive | tar`: archive honours
  # export-ignore (a snapshot missing references/ would fail Checks 2/4) and
  # its failure hides behind tar's exit status.
  GIT_INDEX_FILE=$5.idx git -C "$1" read-tree "$sha" || return 1
  GIT_INDEX_FILE=$5.idx git -C "$1" checkout-index -a --prefix="$5/" || return 1
  # Stand-in repo root: walk-ups (dedup key, Checks 11/14) stop here instead of
  # climbing into the temp dir's parents.
  mkdir "$5/.git" || return 1
  ref="$b@$(git -C "$1" rev-parse --short "$sha")"
  if [ -n "$stale" ]; then
    when=$(git -C "$1" log -1 --format=%cs "$sha")
    printf 'skill-check: fetch %s failed in %s -- using %s from %s\n' "$2" "$1" "$ref" "$when" >&2
    ref="$ref stale:$when"
  fi
  printf '%s\n' "$ref"
}

# emit <repo-top> <scan-dir> [one-SKILL.md] -- rows for one repo. Without
# --snapshot the working tree is audited; with it, the target's default branch.
emit() {
  top=$1; sub=${2#"$1"}; only=${3:-}
  IFS="$tab" read -r host repo src <<EOF
$(target "$top")
EOF
  root=$top; ref=worktree
  if [ "$snap" = 1 ] && [ "$src" != none ]; then
    root=$(mktemp -d "$tmp/snap.XXXXXX")
    if ! ref=$(snapshot "$top" "$src" "$host" "$repo" "$root"); then
      printf '%s\t-\t%s\t%s\tskip\tno %s default-branch ref to snapshot\n' "$top" "$host" "$repo" "$src"
      return
    fi
  fi
  if [ -n "$only" ]; then
    f=$root${only#"$top"}
    if [ -f "$f" ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$top" "$f" "$host" "$repo" "$src" "$ref"
    else
      printf '%s\t-\t%s\t%s\tskip\tnot on %s\n' "$top" "$host" "$repo" "$ref"
    fi
    return
  fi
  if [ ! -d "$root$sub" ]; then
    printf '%s\t-\t%s\t%s\tskip\tnot on %s\n' "$top" "$host" "$repo" "$ref"
    return
  fi
  for f in $(discover "$root$sub"); do
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$top" "$f" "$host" "$repo" "$src" "$ref"
  done
}

toplevel() { git -C "$1" rev-parse --show-toplevel 2>/dev/null && return; printf '%s\n' "$1"; }

scan() {
  [ $# -ge 2 ] || die "usage: skill_scan.sh scan <mode> <target> [--snapshot] [--tmp <dir>]"
  mode=$1; tgt=$2; shift 2
  snap=0; tmp=
  while [ $# -gt 0 ]; do
    case $1 in
      --snapshot) snap=1; shift ;;
      --tmp) [ $# -ge 2 ] || die "--tmp needs a value"; tmp=$2; shift 2 ;;
      *) die "unknown scan option: $1" ;;
    esac
  done
  if [ "$snap" = 1 ] || [ "$mode" = repo ]; then
    if [ -z "$tmp" ] || [ ! -d "$tmp" ]; then die "$mode needs --tmp <existing dir>"; fi
  fi
  case $mode in
    single)
      f=$(abspath "$tgt"); d=$(dirname "$f")
      top=$(abspath "$(toplevel "$d")")
      emit "$top" "$d" "$f" ;;
    dir)
      d=$(abspath "$tgt"); top=$(abspath "$(toplevel "$d")")
      emit "$top" "$d" ;;
    recursive)
      seen=
      for c in $(child_repos "$(abspath "$tgt")"); do
        t=$(target "$c"); k=$(printf '%s' "$t" | cut -f1,2)
        if [ "$(printf '%s' "$t" | cut -f3)" != none ]; then
          first=$(printf '%s\n' "$seen" | awk -F'\t' -v k="$k" '$1 "\t" $2 == k { print $3; exit }')
          if [ -n "$first" ]; then
            printf '%s\t-\t%s\tdup\tsame target as %s/\n' "$c" "$k" "$(basename "$first")"
            continue
          fi
          seen="$seen
$k$tab$c"
        fi
        emit "$c" "$c"
      done ;;
    repo)
      t=$(parse_url "$tgt") || die "not a git URL: $tgt"
      host=$(printf '%s' "$t" | cut -f1); repo=$(printf '%s' "$t" | cut -f2)
      # A fresh clone has no upstream remote: a fork parent stands in for it.
      # Only an issue-filing (--snapshot) run needs the target, and the gh call.
      parent=
      [ "$snap" = 0 ] || parent=$(GH_HOST=$host "$GH" repo view "$repo" --json parent \
        --jq 'if .parent then .parent.owner.login + "/" + .parent.name else "" end' 2>/dev/null || true)
      url=$tgt; src=origin
      if [ -n "$parent" ]; then
        # Issues go to the parent, so --snapshot audits the parent's default
        # branch, not the fork's (same URL form, owner/repo swapped).
        [ "$snap" = 0 ] || url=${tgt%%"$repo"*}$parent${tgt#*"$repo"}
        repo=$parent; src=fork-parent
      fi
      dest=$(mktemp -d "$tmp/clone.XXXXXX")
      git clone --quiet --depth 1 "$url" "$dest" 2>/dev/null || die "git clone failed: $url" 3
      ref=clone@$(git -C "$dest" rev-parse --short HEAD)
      for f in $(discover "$dest"); do
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$tgt" "$f" "$host" "$repo" "$src" "$ref"
      done ;;
    *) die "unknown scan mode: $mode" ;;
  esac
}

cmd=${1:-}
[ $# -eq 0 ] || shift
case $cmd in
  args) args "$@" ;;
  resolve) [ $# -eq 1 ] || die "usage: skill_scan.sh resolve <path|plugin:skill|skill>"; resolve "$1" ;;
  scan) scan "$@" ;;
  parse-url) [ $# -eq 1 ] || die "usage: skill_scan.sh parse-url <git-url>"; parse_url "$1" || die "not a git URL: $1" ;;
  key) if [ $# -ne 1 ] || [ ! -f "$1" ]; then die "usage: skill_scan.sh key <SKILL.md>"; fi; key "$1" ;;
  *) die "usage: skill_scan.sh args|resolve|scan|parse-url|key ... (see the header)" ;;
esac
