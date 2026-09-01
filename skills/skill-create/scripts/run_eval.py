#!/usr/bin/env python3
"""Run trigger evaluation for a skill description.

Tests whether a skill's description causes Claude to trigger (read the skill)
for a set of queries. Outputs results as JSON.
"""

import argparse
import json
import os
import select
import subprocess
import sys
import tempfile
import time
import uuid
from collections.abc import Iterable
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

from scripts.utils import format_result_lines, parse_skill_md


def find_project_root() -> Path:
    """Find the project root by walking up from cwd looking for .claude/.

    Mimics how Claude Code discovers its project root, so the command file
    we create ends up where claude -p will look for it.
    """
    current = Path.cwd()
    for parent in [current, *current.parents]:
        if (parent / ".claude").is_dir():
            return parent
    return current


# --- LOCAL PATCH (dotfiles #1412) -------------------------------------------
# Upstream `run_eval.py` decided the whole query at the FIRST tool block:
#   * a non-Skill/Read block returned False outright, and
#   * `content_block_stop` returned `clean_name in accumulated_json`.
# When an installed skill shares the evaluated description it answers before
# the uuid probe, so every real trigger was scored 0. The state machine below
# inspects every block and only settles on a negative at end of stream.
# Re-apply (or drop, if upstream fixed it) when this skill is re-imported.
# ----------------------------------------------------------------------------
class TriggerDetector:
    """Decide whether a `claude -p` stream invoked the uuid-named probe.

    Fed one stream-json line at a time. `feed` returns True the moment the
    probe name is confirmed, so callers can stop reading early; a negative
    verdict is only known once the stream ends.
    """

    def __init__(self, clean_name: str) -> None:
        self.clean_name = clean_name
        self.triggered = False
        self.finished = False
        self._in_probe_block = False
        self._accumulated = ""

    def feed(self, line: str) -> bool:
        """Consume one line of `--output-format stream-json`; True once triggered."""
        line = line.strip()
        if not line:
            return self.triggered

        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            return self.triggered

        event_type = event.get("type")

        if event_type == "stream_event":
            se = event.get("event", {})
            se_type = se.get("type", "")

            if se_type == "content_block_start":
                # A block that is neither Skill nor Read simply carries no
                # verdict — it must not end the query (upstream returned False).
                cb = se.get("content_block", {})
                self._in_probe_block = cb.get("type") == "tool_use" and cb.get("name", "") in ("Skill", "Read")
                self._accumulated = ""

            elif se_type == "content_block_delta" and self._in_probe_block:
                delta = se.get("delta", {})
                if delta.get("type") == "input_json_delta":
                    self._accumulated += delta.get("partial_json", "")
                    if self.clean_name in self._accumulated:
                        self.triggered = True

            elif se_type == "content_block_stop":
                self._in_probe_block = False

            elif se_type == "message_stop":
                self.finished = True

        # Fallback: the full assistant message, which arrives after tool
        # execution. Scan every content item, not just the first.
        elif event_type == "assistant":
            for content_item in event.get("message", {}).get("content", []):
                if content_item.get("type") != "tool_use":
                    continue
                tool_name = content_item.get("name", "")
                # `or {}` not `get(..., {})`: an explicitly null "input" is a
                # present key, so the default never applies (PR #1422, agy).
                tool_input = content_item.get("input") or {}
                if tool_name == "Skill" and self.clean_name in tool_input.get("skill", ""):
                    self.triggered = True
                elif tool_name == "Read" and self.clean_name in tool_input.get("file_path", ""):
                    self.triggered = True

        elif event_type == "result":
            self.finished = True

        return self.triggered


def detect_trigger(lines: Iterable[str], clean_name: str) -> bool:
    """Scan a whole `claude -p` stream and report whether the probe was invoked."""
    detector = TriggerDetector(clean_name)
    return any(detector.feed(line) for line in lines)


# --- LOCAL PATCH (dotfiles #1412, F-2) --------------------------------------
# Upstream sent the subprocess' stderr to DEVNULL, so an auth expiry, the
# nesting guard or a timeout reported the same `trigger_rate 0.0` as a
# description that genuinely never fires. Every run now carries an explicit
# error slot, and errored runs are excluded from the trigger-rate denominator.
# ----------------------------------------------------------------------------
STDERR_EXCERPT_CHARS = 500


def _outcome(triggered: bool, error: str | None = None) -> dict:
    """One run's verdict: did the probe fire, and did the harness itself work."""
    return {"triggered": triggered, "error": error}


def _read_stderr(handle) -> str:
    try:
        handle.seek(0)
        text = handle.read().decode("utf-8", errors="replace").strip()
    except (OSError, ValueError):
        return ""
    return text[-STDERR_EXCERPT_CHARS:]


# --- LOCAL PATCH (dotfiles #1412, F-3) --------------------------------------
# The probe command is offered to the model next to every installed skill. When
# one of them carries the same name (and therefore, typically, the same
# description) the model reasonably answers with the real skill. F-1 makes that
# case score correctly, but the run is still noisier than an isolated one — so
# name the shadowing skills instead of letting the user guess.
# ----------------------------------------------------------------------------
def _normalize_skill_name(name: str) -> str:
    return name.strip().lower().replace(":", "-").replace("_", "-")


def find_shadowing_skills(skill_name: str, project_root: Path, skill_path: Path | None = None) -> list[Path]:
    """Installed skill directories whose name matches the one being evaluated."""
    wanted = _normalize_skill_name(skill_name)
    evaluated = skill_path.resolve() if skill_path else None

    roots = [Path(project_root) / ".claude" / "skills"]
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR")
    if config_dir:
        roots.append(Path(config_dir) / "skills")
    roots.append(Path.home() / ".claude" / "skills")

    found: list[Path] = []
    seen: set[Path] = set()
    for root in roots:
        if not root.is_dir():
            continue
        for candidate in sorted(root.iterdir()):
            if not candidate.is_dir() or _normalize_skill_name(candidate.name) != wanted:
                continue
            resolved = candidate.resolve()
            if resolved == evaluated or resolved in seen:
                continue
            seen.add(resolved)
            found.append(candidate)
    return found


# LOCAL PATCH (dotfiles #1428): `run_loop` needs the same warning, and a second
# copy of the wording is how F-2's rules drifted apart in the first place.
def warn_shadowing_skills(skill_name: str, project_root: Path, skill_path: Path | None = None) -> None:
    """Print one F-3 warning per installed skill shadowing the one evaluated."""
    for shadow in find_shadowing_skills(skill_name, project_root, skill_path=skill_path):
        print(
            f"Warning: installed skill '{skill_name}' shadows this eval at {shadow} — "
            "the model may answer with it instead of the probe. "
            "Run with an isolated CLAUDE_CONFIG_DIR for a clean signal.",
            file=sys.stderr,
        )


def run_single_query(
    query: str,
    skill_name: str,
    skill_description: str,
    timeout: int,
    project_root: str,
    model: str | None = None,
) -> dict:
    """Run a single query and report whether the skill was triggered.

    Returns `{"triggered": bool, "error": str | None}` — a non-None error means
    the harness itself failed, which is not the same as "did not trigger".

    Creates a command file in .claude/commands/ so it appears in Claude's
    available_skills list, then runs `claude -p` with the raw query.
    Uses --include-partial-messages to detect triggering early from
    stream events (content_block_start) rather than waiting for the
    full assistant message, which only arrives after tool execution.
    """
    unique_id = uuid.uuid4().hex[:8]
    clean_name = f"{skill_name}-skill-{unique_id}"
    project_commands_dir = Path(project_root) / ".claude" / "commands"
    command_file = project_commands_dir / f"{clean_name}.md"
    stderr_buf = None

    try:
        project_commands_dir.mkdir(parents=True, exist_ok=True)
        # Use YAML block scalar to avoid breaking on quotes in description
        indented_desc = "\n  ".join(skill_description.split("\n"))
        command_content = (
            f"---\n"
            f"description: |\n"
            f"  {indented_desc}\n"
            f"---\n\n"
            f"# {skill_name}\n\n"
            f"This skill handles: {skill_description}\n"
        )
        command_file.write_text(command_content)

        cmd = [
            "claude",
            "-p",
            query,
            "--output-format",
            "stream-json",
            "--verbose",
            "--include-partial-messages",
        ]
        if model:
            cmd.extend(["--model", model])

        # Remove CLAUDECODE env var to allow nesting claude -p inside a
        # Claude Code session. The guard is for interactive terminal conflicts;
        # programmatic subprocess usage is safe.
        env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}

        # LOCAL PATCH (dotfiles #1412, F-2): a file, not a pipe — a pipe's
        # stderr can fill and deadlock a reader that only drains stdout.
        stderr_buf = tempfile.TemporaryFile()
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=stderr_buf,
            cwd=project_root,
            env=env,
        )

        detector = TriggerDetector(clean_name)
        start_time = time.time()
        buffer = ""

        try:
            while time.time() - start_time < timeout:
                if process.poll() is not None:
                    remaining = process.stdout.read()
                    if remaining:
                        buffer += remaining.decode("utf-8", errors="replace")
                    break

                ready, _, _ = select.select([process.stdout], [], [], 1.0)
                if not ready:
                    continue

                chunk = os.read(process.stdout.fileno(), 8192)
                if not chunk:
                    break
                buffer += chunk.decode("utf-8", errors="replace")

                *lines, buffer = buffer.split("\n")
                if any(detector.feed(line) for line in lines):
                    return _outcome(True)
                if detector.finished:
                    break

            # LOCAL PATCH (dotfiles #1412, F-1): drain the tail. Upstream read
            # `remaining` into the buffer and then broke out without parsing it
            # — harmless while the first tool block decided the verdict,
            # load-bearing now that it doesn't.
            for line in buffer.split("\n"):
                detector.feed(line)
            if detector.triggered:
                return _outcome(True)

            # LOCAL PATCH (dotfiles #1412, F-2): an EOF immediately followed by
            # exit must not read as a timeout.
            if process.poll() is None and not detector.finished:
                try:
                    process.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    pass
            returncode = process.poll()
            timed_out = returncode is None and not detector.finished
        finally:
            # Clean up process on any exit path (return, exception, timeout)
            if process.poll() is None:
                process.kill()
                process.wait()

        if timed_out:
            return _outcome(False, f"claude -p exceeded the {timeout}s timeout: {_read_stderr(stderr_buf)}".strip())
        if returncode:
            return _outcome(False, f"claude -p exited {returncode}: {_read_stderr(stderr_buf)}".strip())
        return _outcome(False)
    finally:
        if stderr_buf is not None:
            stderr_buf.close()
        if command_file.exists():
            command_file.unlink()


def run_eval(
    eval_set: list[dict],
    skill_name: str,
    description: str,
    num_workers: int,
    timeout: int,
    project_root: Path,
    runs_per_query: int = 1,
    trigger_threshold: float = 0.5,
    model: str | None = None,
) -> dict:
    """Run the full eval set and return results."""
    results = []

    with ProcessPoolExecutor(max_workers=num_workers) as executor:
        future_to_info = {}
        for item in eval_set:
            for run_idx in range(runs_per_query):
                future = executor.submit(
                    run_single_query,
                    item["query"],
                    skill_name,
                    description,
                    timeout,
                    str(project_root),
                    model,
                )
                future_to_info[future] = (item, run_idx)

        query_outcomes: dict[str, list[dict]] = {}
        query_items: dict[str, dict] = {}
        for future in as_completed(future_to_info):
            item, _ = future_to_info[future]
            query = item["query"]
            query_items[query] = item
            if query not in query_outcomes:
                query_outcomes[query] = []
            try:
                query_outcomes[query].append(future.result())
            except Exception as e:
                print(f"Warning: query failed: {e}", file=sys.stderr)
                query_outcomes[query].append(_outcome(False, f"worker raised: {e}"))

    # LOCAL PATCH (dotfiles #1412, F-2): runs whose harness failed are held out
    # of the trigger-rate denominator, and a query with nothing usable left can
    # never be scored a pass — otherwise a dead `claude -p` silently "passes"
    # every should-not-trigger query.
    for query, outcomes in query_outcomes.items():
        item = query_items[query]
        errors = [o["error"] for o in outcomes if o.get("error")]
        usable = [o for o in outcomes if not o.get("error")]
        triggers = sum(1 for o in usable if o["triggered"])
        trigger_rate = triggers / len(usable) if usable else 0.0
        should_trigger = item["should_trigger"]
        if not usable:
            did_pass = False
        elif should_trigger:
            did_pass = trigger_rate >= trigger_threshold
        else:
            did_pass = trigger_rate < trigger_threshold
        results.append(
            {
                "query": query,
                "should_trigger": should_trigger,
                "trigger_rate": trigger_rate,
                "triggers": triggers,
                "runs": len(outcomes),
                "usable_runs": len(usable),
                "errors": len(errors),
                "error_samples": errors[:3],
                "pass": did_pass,
            }
        )

    passed = sum(1 for r in results if r["pass"])
    total = len(results)

    return {
        "skill_name": skill_name,
        "description": description,
        "results": results,
        "summary": {
            "total": total,
            "passed": passed,
            "failed": total - passed,
            "errors": sum(r["errors"] for r in results),
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Run trigger evaluation for a skill description")
    parser.add_argument("--eval-set", required=True, help="Path to eval set JSON file")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--description", default=None, help="Override description to test")
    parser.add_argument("--num-workers", type=int, default=10, help="Number of parallel workers")
    parser.add_argument("--timeout", type=int, default=30, help="Timeout per query in seconds")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Number of runs per query")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Trigger rate threshold")
    parser.add_argument("--model", default=None, help="Model to use for claude -p (default: user's configured model)")
    parser.add_argument("--verbose", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    eval_set = json.loads(Path(args.eval_set).read_text())
    skill_path = Path(args.skill_path)

    if not (skill_path / "SKILL.md").exists():
        print(f"Error: No SKILL.md found at {skill_path}", file=sys.stderr)
        sys.exit(1)

    name, original_description, content = parse_skill_md(skill_path)
    description = args.description or original_description
    project_root = find_project_root()

    if args.verbose:
        print(f"Evaluating: {description}", file=sys.stderr)

    # LOCAL PATCH (dotfiles #1412, F-3): always warn — a forgotten isolation
    # step is the reason this eval silently reported zeros.
    warn_shadowing_skills(name, project_root, skill_path=skill_path)

    output = run_eval(
        eval_set=eval_set,
        skill_name=name,
        description=description,
        num_workers=args.num_workers,
        timeout=args.timeout,
        project_root=project_root,
        runs_per_query=args.runs_per_query,
        trigger_threshold=args.trigger_threshold,
        model=args.model,
    )

    if args.verbose:
        summary = output["summary"]
        headline = f"Results: {summary['passed']}/{summary['total']} passed"
        if summary["errors"]:
            headline += f"  ({summary['errors']} run(s) never executed)"
        print(headline, file=sys.stderr)
        for r in output["results"]:
            # LOCAL PATCH (dotfiles #1412, F-2): a run the harness could not
            # execute says nothing about the description — label it apart from
            # FAIL, and print what actually went wrong. Shared with `run_loop`
            # since #1428.
            for line in format_result_lines(r):
                print(line, file=sys.stderr)

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
