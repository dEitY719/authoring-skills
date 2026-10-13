#!/bin/sh
# Runs the skill-create helper's own self-check. The CI step that discovers
# `tests/*.sh` is the only thing that needs to know this file exists.
set -eu
exec sh "$(dirname "$0")/../skills/skill-create/lib/selftest.sh"
