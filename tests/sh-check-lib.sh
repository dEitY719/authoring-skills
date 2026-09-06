#!/bin/sh
# Runs the sh-check helper's own self-check. The CI step that discovers
# `tests/*.sh` is the only thing that needs to know this file exists.
set -eu
exec sh "$(dirname "$0")/../skills/sh-check/lib/selftest.sh"
