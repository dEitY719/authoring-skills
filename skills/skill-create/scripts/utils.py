"""Shared utilities for authoring:skill-create scripts."""

from pathlib import Path


# --- LOCAL PATCH (dotfiles #1412, F-2) --------------------------------------
# `run_eval()` counts `triggers` over the runs that actually executed, but
# `runs` stayed the raw attempt count. Every consumer that divides one by the
# other has to use this denominator instead, or a dead harness reads as a
# perfect score (PR #1422 review, codex + /simplify altitude pass).
# ----------------------------------------------------------------------------
def usable_runs(result: dict) -> int:
    """Runs that produced evidence about the description, errored ones excluded."""
    return result.get("usable_runs", result["runs"])


# --- LOCAL PATCH (dotfiles #1428) -------------------------------------------
# `run_eval.main()` and `run_loop()` each rendered the per-query verbose line
# themselves, and only `main()` ever learned the F-2 rules — so the documented
# entry point (`python -m scripts.run_loop`) still printed `[FAIL] rate=0/2`
# for a harness that never ran. One formatter, both callers.
# ----------------------------------------------------------------------------
def format_result_lines(result: dict) -> list[str]:
    """Verbose stderr lines for one eval result: status row, then any errors."""
    if result.get("errors") and not usable_runs(result):
        status = "ERROR"
    else:
        status = "PASS" if result["pass"] else "FAIL"
    lines = [
        f"  [{status}] rate={result['triggers']}/{usable_runs(result)} "
        f"expected={result['should_trigger']}: {result['query'][:70]}"
    ]
    lines += [f"      ! {sample}" for sample in result.get("error_samples", [])]
    return lines


def parse_skill_md(skill_path: Path) -> tuple[str, str, str]:
    """Parse a SKILL.md file, returning (name, description, full_content)."""
    content = (skill_path / "SKILL.md").read_text()
    lines = content.split("\n")

    if lines[0].strip() != "---":
        raise ValueError("SKILL.md missing frontmatter (no opening ---)")

    end_idx = None
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            end_idx = i
            break

    if end_idx is None:
        raise ValueError("SKILL.md missing frontmatter (no closing ---)")

    name = ""
    description = ""
    frontmatter_lines = lines[1:end_idx]
    i = 0
    while i < len(frontmatter_lines):
        line = frontmatter_lines[i]
        if line.startswith("name:"):
            name = line[len("name:") :].strip().strip('"').strip("'")
        elif line.startswith("description:"):
            value = line[len("description:") :].strip()
            # Handle YAML multiline indicators (>, |, >-, |-)
            if value in (">", "|", ">-", "|-"):
                continuation_lines: list[str] = []
                i += 1
                while i < len(frontmatter_lines) and (
                    frontmatter_lines[i].startswith("  ") or frontmatter_lines[i].startswith("\t")
                ):
                    continuation_lines.append(frontmatter_lines[i].strip())
                    i += 1
                description = " ".join(continuation_lines)
                continue
            else:
                description = value.strip('"').strip("'")
        i += 1

    return name, description, content
