#!/usr/bin/env bash
# tests/bats/test_helper.bash -- shared setup for this repo's bats suites.
# Needs BATS_LIB_PATH pointing at a dir holding bats-support and bats-assert.

bats_load_library bats-support
bats_load_library bats-assert

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT
