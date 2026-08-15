# Portable Agent Handoff Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the repository safely self-configuring on a new Mac and publish it with complete human and agent instructions.

**Architecture:** A Bash `setup` command detects the target Mac's default interface, private IPv4, and reachable loopback proxy, then renders an ignored local environment file from a committed example. The lifecycle CLI continues to use GOST through `launchctl`, with `caffeinate -i` wrapping the process so display sleep does not interrupt Switch downloads.

**Tech Stack:** macOS Bash 3.2, GOST v3, launchctl, caffeinate, curl, nc, lsof, GitHub CLI

---

### Task 1: Portable configuration detection

**Files:**
- Modify: `tests/nintendo-acc-test.sh`
- Modify: `lib/nintendo_acc.sh`
- Create: `config/nintendo-acc.env.example`
- Delete: `config/nintendo-acc.env`
- Modify: `.gitignore`

**Step 1: Write the failing test**

Add tests for default-interface parsing, private-IP configuration rendering, loopback upstream selection, empty example values, and ignored local configuration.

**Step 2: Run test to verify it fails**

Run: `bash tests/nintendo-acc-test.sh`

Expected: FAIL because detection/rendering helpers and the portable example do not exist.

**Step 3: Write minimal implementation**

Implement pure helpers in `lib/nintendo_acc.sh`, replace the committed runtime config with a blank example, and ignore the generated file.

**Step 4: Run test to verify it passes**

Run: `bash tests/nintendo-acc-test.sh`

Expected: all Task 1 tests PASS.

**Step 5: Commit**

```bash
git add .gitignore config lib tests
git commit -m "feat: generate machine-local proxy configuration"
```

### Task 2: Setup command and sleep-safe runtime

**Files:**
- Modify: `tests/nintendo-acc-test.sh`
- Modify: `bin/nintendo-acc`
- Modify: `lib/nintendo_acc.sh`

**Step 1: Write the failing test**

Add CLI contract tests for `setup`, missing local configuration, environment overrides, and launch arguments containing `/usr/bin/caffeinate -i` before GOST.

**Step 2: Run test to verify it fails**

Run: `bash tests/nintendo-acc-test.sh`

Expected: FAIL because `setup` and caffeinate wrapping are absent.

**Step 3: Write minimal implementation**

Add `setup` to detect/generate safely, preserve explicit overrides, print Switch values, and wrap the launchd-managed GOST process with caffeinate.

**Step 4: Run test to verify it passes**

Run: `bash -n bin/nintendo-acc lib/nintendo_acc.sh tests/nintendo-acc-test.sh && bash tests/nintendo-acc-test.sh`

Expected: syntax and all tests PASS.

**Step 5: Commit**

```bash
git add bin lib tests
git commit -m "feat: add portable setup and sleep-safe runtime"
```

### Task 3: Human and agent documentation

**Files:**
- Modify: `tests/nintendo-acc-test.sh`
- Modify: `README.md`
- Create: `PROMPT.md`
- Create: `AGENTS.md`

**Step 1: Write the failing documentation contract**

Require clone/setup/start instructions, no actual machine IP, canonical agent rules, security constraints, approval boundaries, sleep caveats, and Switch placeholders.

**Step 2: Run test to verify it fails**

Run: `bash tests/nintendo-acc-test.sh`

Expected: FAIL because the handoff documents do not yet exist and README is machine-specific.

**Step 3: Write minimal documentation**

Rewrite README as a clean-checkout guide, create a copy-paste target-agent prompt, and define repository rules in `AGENTS.md`.

**Step 4: Run test to verify it passes**

Run: `bash tests/nintendo-acc-test.sh`

Expected: all documentation contracts PASS.

**Step 5: Commit**

```bash
git add README.md PROMPT.md AGENTS.md tests/nintendo-acc-test.sh docs/plans
git commit -m "docs: add reproducible agent handoff"
```

### Task 4: Public GitHub release

**Files:**
- Review: all tracked files

**Step 1: Verify implementation**

Run: `bash -n bin/nintendo-acc lib/nintendo_acc.sh tests/nintendo-acc-test.sh && bash tests/nintendo-acc-test.sh`

Expected: syntax exits 0 and all tests PASS.

**Step 2: Scan for machine data and secrets**

Run targeted scans for credentials, subscription URLs, private keys, runtime logs, actual machine IP, and unignored `.env` files.

Expected: no publish-blocking findings.

**Step 3: Review tracked files**

Run: `git status --short && git ls-files`

Expected: only intentional source, docs, tests, examples, and plans.

**Step 4: Create and push public repository**

Run: `gh repo create Miss-you/nintendo-acc --public --source=. --remote=origin --push`

Expected: public repository created and `main` pushed.

**Step 5: Verify remote**

Run: `gh repo view Miss-you/nintendo-acc --json nameWithOwner,visibility,url,defaultBranchRef` and inspect remote `README.md`, `PROMPT.md`, and `AGENTS.md`.

Expected: repository is PUBLIC, default branch is `main`, and all three documents are readable.

Execute with `@test-driven-development`, scan with `@secret-scan` before every commit/push, publish with `@github:yeet`, and use `@verification-before-completion` before reporting success.
