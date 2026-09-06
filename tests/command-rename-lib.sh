#!/bin/sh
# Runs the command-rename helpers' own self-check. The CI step that discovers
# `tests/*.sh` is the only thing that needs to know this file exists.
set -eu
exec sh "$(dirname "$0")/../skills/command-rename/lib/selftest.sh"
