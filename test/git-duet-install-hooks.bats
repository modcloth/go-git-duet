#!/usr/bin/env bats

load test_helper

@test "writes the hook to the pre-commit hook file" {
  git duet-install-hook -q
  assert_success
  [ -f .git/hooks/pre-commit ]
}

@test "makes the pre-commit hook executable" {
  git duet-install-hook -q
  assert_success
  [ -x .git/hooks/pre-commit ]
}
