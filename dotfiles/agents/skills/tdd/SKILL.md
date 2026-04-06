---
name: tdd
description: Test-driven bug fixing and feature development. Use when fixing bugs or building features — works with test suites or ad-hoc repro scripts. Enforces red-green-refactor vertical slices.
---

# Test-Driven Development

## Choosing a Mode

First, determine which mode fits the project:

- **Test suite mode**: The project has an existing test runner (vitest, pytest, cargo test, go test, etc.). Write tests using the project's framework.
- **Ad-hoc mode**: No test suite, or the bug is easier to reproduce outside one. Write a standalone repro script in `./tmp/repro/`. This directory is gitignored scratch space — create it if it doesn't exist.

Both modes follow the same red-green discipline. The only difference is where the "test" lives.

## Bug Fix Workflow

This is the primary workflow. Do NOT attempt a fix before you have a failing repro.

### 1. Isolate

- Understand the bug. Read the relevant code. Identify the minimal conditions that trigger it.
- Narrow down: which input, which code path, which state.

### 2. RED — Reproduce

**Test suite mode**: Write a failing test case in the project's test framework that captures the broken behavior. Run the suite — confirm it fails for the right reason.

**Ad-hoc mode**: Write a self-contained repro script in `./tmp/repro/`:

```
./tmp/repro/
├── repro.sh          # or repro.js, repro.py, etc.
├── input.txt         # test fixtures if needed
└── expected-output   # what correct behavior looks like
```

The repro script should:
- Exit 0 on correct behavior, exit 1 on bug
- Print a clear message: what was expected vs what happened
- Be runnable in one command (e.g. `bash ./tmp/repro/repro.sh`)
- Reference project files by relative path from project root

Run it. Confirm it fails (exit 1). This is your proof the bug exists.

### 3. GREEN — Fix

- Fix the bug with minimal changes.
- Run the repro again. Confirm it passes (exit 0).

### 4. Verify

- **Test suite mode**: Run the full test suite to check for regressions.
- **Ad-hoc mode**: Run the repro script, plus manually verify the fix makes sense in context. If there are any existing tests in the project, run those too.

## Feature Workflow

### 1. Planning

Before writing any code:

- [ ] Confirm with user what interface changes are needed
- [ ] Confirm with user which behaviors to test (prioritize)
- [ ] Design interfaces for [testability](interface-design.md)
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

**You can't test everything.** Focus on critical paths and complex logic, not every possible edge case.

### 2. Vertical Slices

One test → one implementation → repeat.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

**DO NOT write all tests first.** Tests written in bulk test _imagined_ behavior, not _actual_ behavior. Each test should respond to what you learned from the previous cycle.

Rules:
- One test at a time
- Only enough code to pass current test
- Don't anticipate future tests
- Keep tests focused on observable behavior

### 3. Refactor

After all tests pass, look for [refactor candidates](refactoring.md). **Never refactor while RED.** Get to GREEN first.

## Test Quality

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

**Good tests** verify behavior through public interfaces. They describe _what_ the system does, survive internal refactors, and read like specifications.

**Bad tests** are coupled to implementation: mocking internal collaborators, testing private methods, asserting on call counts. Warning sign: test breaks when you refactor but behavior hasn't changed.

Mock only at **system boundaries** (external APIs, databases, time/randomness). Don't mock your own code.

## Checklist Per Cycle

```
[ ] Test/repro describes behavior, not implementation
[ ] Test/repro uses public interface only
[ ] Test/repro would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
```
