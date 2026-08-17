# Manual Start Checklist Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a local Nintendo proxy startup checklist, install and configure GOST, start the service manually, and verify the complete proxy chain.

**Architecture:** Keep service lifecycle behavior in the existing `bin/nintendo-acc` CLI. Add only a local README in the parent directory as an operator checklist; do not add login persistence, a privileged daemon, or a second startup script.

**Tech Stack:** Markdown, macOS Bash 3.2, Homebrew, GOST v3, launchctl, caffeinate, curl

---

### Task 1: Create the manual startup checklist

**Files:**
- Create: `../开机启动服务列表/README.md`

**Step 1: Run a failing document contract**

Check that the README exists and contains `preflight`, `start`, `status`, `test`, `switch`, and `stop` commands.

**Step 2: Verify the contract fails**

Run a read-only Bash assertion against `../开机启动服务列表/README.md`.

Expected: FAIL because the README does not exist.

**Step 3: Write the minimal README**

Create a Nintendo-only checkbox list that starts the local proxy core, enters `~/Documents/Github/nintendo-acc`, runs preflight/start/verification commands, explains recovery after a network change, and documents shutdown.

**Step 4: Verify the contract passes**

Run the same Bash assertion.

Expected: PASS with every required command present and no machine-specific IP or credential pattern.

### Task 2: Install and configure the service

**Files:**
- Create locally: `config/nintendo-acc.env`

**Step 1: Install the runtime dependency**

Run: `brew install gost`

Expected: Homebrew installs GOST or reports that it is already installed.

**Step 2: Generate local configuration**

Run: `bin/nintendo-acc setup`

Expected: setup detects the default interface, current RFC1918 address, and a loopback upstream, then creates `config/nintendo-acc.env` with mode `600`.

**Step 3: Run preflight**

Run: `bin/nintendo-acc preflight`

Expected: the configured address belongs to the current interface, the upstream is reachable, and the listening port is free.

### Task 3: Start and verify the proxy

**Files:**
- Create locally: `.runtime/gost.log`

**Step 1: Start the service**

Run: `bin/nintendo-acc start`

Expected: the current login session owns a launchctl job wrapping GOST with `/usr/bin/caffeinate -i`.

**Step 2: Verify runtime status**

Run: `bin/nintendo-acc status`

Expected: running PID and the configured private HTTP listener.

**Step 3: Verify the HTTPS chain**

Run: `bin/nintendo-acc test`

Expected: a nonzero HTTP status from the configured Nintendo HTTPS probe through GOST and the loopback upstream.

**Step 4: Print Switch settings**

Run: `bin/nintendo-acc switch`

Expected: actual private server address, port, and authentication disabled.

### Task 4: Final quality and safety checks

**Files:**
- Verify: `../开机启动服务列表/README.md`
- Verify: repository source and ignored runtime files

**Step 1: Run repository verification**

Run: `bash -n bin/nintendo-acc lib/nintendo_acc.sh tests/nintendo-acc-test.sh && bash tests/nintendo-acc-test.sh`

Expected: syntax checks and all tests pass.

**Step 2: Run source hygiene checks**

Run `git diff --check`, inspect `git status --short`, verify local config/runtime paths are ignored, and scan changed/tracked content for secrets, machine-specific IPs, usernames, and absolute user paths.

Expected: no publish-blocking findings and no local config or runtime files in Git status.

**Step 3: Re-run live acceptance checks**

Run: `bin/nintendo-acc preflight && bin/nintendo-acc status && bin/nintendo-acc test`

Expected: all three commands exit successfully with current evidence.
