#!/usr/bin/env python3
"""
Quick validation script for skills - minimal version
"""

import re
import sys
from pathlib import Path

import yaml

# Dot-separated labels (1-63 chars) of ASCII letters, digits and inner hyphens:
# rejects `/`, `:`, `*`, `_`, whitespace and a trailing dot, so URLs, ports and
# wildcards cannot slip through. IDNs must be written in punycode (`xn--...`);
# an IPv4 literal matches too. The 253-char total cap is checked at the call site.
_LABEL = r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
HOSTNAME_RE = re.compile(rf"{_LABEL}(?:\.{_LABEL})*")

# Mirrors the "Known attributes" list of skill-check Check 3
# (skills/skill-check/references/checks.md); lib/selftest.sh asserts the two
# stay equal, so add a key there and here together.
ALLOWED_PROPERTIES = frozenset({
    "name", "description", "license", "allowed-tools", "metadata", "compatibility", "allowed_domains",
    "user-invocable", "argument-hint", "disable-model-invocation",
})
# Claude Code's invocation-control keys (other harnesses ignore them) take a
# YAML boolean.
BOOL_PROPERTIES = ("user-invocable", "disable-model-invocation")


def validate_skill(skill_path):
    """Basic validation of a skill"""
    skill_path = Path(skill_path)

    # Check SKILL.md exists
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        return False, "SKILL.md not found"

    # Read and validate frontmatter
    content = skill_md.read_text()
    if not content.startswith("---"):
        return False, "No YAML frontmatter found"

    # Extract frontmatter
    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return False, "Invalid frontmatter format"

    frontmatter_text = match.group(1)

    # Parse YAML frontmatter
    try:
        frontmatter = yaml.safe_load(frontmatter_text)
        if not isinstance(frontmatter, dict):
            return False, "Frontmatter must be a YAML dictionary"
    except yaml.YAMLError as e:
        return False, f"Invalid YAML in frontmatter: {e}"

    # Check for unexpected properties (excluding nested keys under metadata).
    # str() first: YAML turns keys such as `on:` or `1:` into bool/int, which
    # would otherwise crash the join below.
    unexpected_keys = set(frontmatter.keys()) - ALLOWED_PROPERTIES
    if unexpected_keys:
        return False, (
            f"Unexpected key(s) in SKILL.md frontmatter: {', '.join(sorted(map(str, unexpected_keys)))}. "
            f"Allowed properties are: {', '.join(sorted(ALLOWED_PROPERTIES))}"
        )

    # Check required fields
    if "name" not in frontmatter:
        return False, "Missing 'name' in frontmatter"
    if "description" not in frontmatter:
        return False, "Missing 'description' in frontmatter"

    # Extract name for validation
    name = frontmatter.get("name", "")
    if not isinstance(name, str):
        return False, f"Name must be a string, got {type(name).__name__}"
    name = name.strip()
    if name:
        # Check naming convention (kebab-case: lowercase with hyphens)
        if not re.match(r"^[a-z0-9-]+$", name):
            return False, f"Name '{name}' should be kebab-case (lowercase letters, digits, and hyphens only)"
        if name.startswith("-") or name.endswith("-") or "--" in name:
            return False, f"Name '{name}' cannot start/end with hyphen or contain consecutive hyphens"
        # Check name length (max 64 characters per spec)
        if len(name) > 64:
            return False, f"Name is too long ({len(name)} characters). Maximum is 64 characters."

    # Extract and validate description
    description = frontmatter.get("description", "")
    if not isinstance(description, str):
        return False, f"Description must be a string, got {type(description).__name__}"
    description = description.strip()
    if description:
        # Check for angle brackets
        if "<" in description or ">" in description:
            return False, "Description cannot contain angle brackets (< or >)"
        # Check description length (max 1024 characters per spec)
        if len(description) > 1024:
            return False, f"Description is too long ({len(description)} characters). Maximum is 1024 characters."

    # Validate compatibility field if present (optional). Accepts either a
    # free-text string or the structured mapping form already used elsewhere
    # in this repo (e.g. `compatibility: {tools: ..., network: required}`).
    compatibility = frontmatter.get("compatibility", "")
    if compatibility:
        if isinstance(compatibility, str):
            if len(compatibility) > 500:
                return False, f"Compatibility is too long ({len(compatibility)} characters). Maximum is 500 characters."
        elif not isinstance(compatibility, dict):
            return False, f"Compatibility must be a string or mapping, got {type(compatibility).__name__}"

    # Invocation-control keys: a quoted "false" is a truthy string, so a
    # skill meant to be hidden would silently stay invocable.
    for key in BOOL_PROPERTIES:
        if key in frontmatter and not isinstance(frontmatter[key], bool):
            got = "an empty value" if frontmatter[key] is None else repr(frontmatter[key])
            return False, f"{key} must be an unquoted true or false, got {got}"

    # Validate allowed_domains if present: a non-empty list of literal
    # hostnames, as skill-check's Check 3 requires (no wildcards, URLs, ports
    # or whitespace; IDNs in punycode).
    if "allowed_domains" in frontmatter:
        domains = frontmatter["allowed_domains"]
        if not isinstance(domains, list):
            return False, f"allowed_domains must be a list of hostnames, got {type(domains).__name__}"
        # An empty allowlist names no host; omit the key instead.
        if not domains:
            return False, "allowed_domains must list at least one hostname (omit the key if the skill needs none)"
        for domain in domains:
            if not isinstance(domain, str) or len(domain) > 253 or not HOSTNAME_RE.fullmatch(domain):
                return False, (
                    f"allowed_domains entry {domain!r} is not a plain hostname "
                    "(ASCII labels only: no scheme, path, port, wildcard, whitespace or trailing dot; e.g. fonts.gstatic.com)"
                )
        # Check 3 pairs allowed_domains with `compatibility.network: required`;
        # this script is deliberately stricter than Check 3's grading and
        # fails an unpaired or empty allowlist outright.
        # A free-text compatibility string cannot be parsed reliably, so it is
        # left alone; a missing, empty or mapping-form compatibility is checked.
        if not (isinstance(compatibility, str) and compatibility.strip()):
            network = compatibility.get("network") if isinstance(compatibility, dict) else None
            if network != "required":
                got = "no compatibility.network" if network is None else f"got network: {network!r}"
                return False, f"allowed_domains requires compatibility.network: required ({got})"

    return True, "Skill is valid!"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python quick_validate.py <skill_directory>")
        sys.exit(1)

    valid, message = validate_skill(sys.argv[1])
    print(message)
    sys.exit(0 if valid else 1)
