#!/bin/sh
# Runs the ux-guidelines helper's own self-check. The CI step that discovers
# `tests/*.sh` is the only thing that needs to know this file exists.
set -eu
exec sh "$(dirname "$0")/../skills/ux-guidelines/lib/selftest.sh"
