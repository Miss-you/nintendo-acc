# Portable Agent Handoff Design

## Goal

Publish `Miss-you/nintendo-acc` as a public, self-configuring macOS project that another coding agent can clone and run without inheriting this Mac's LAN address, proxy credentials, or runtime state.

## Chosen approach

Use the existing tested Bash CLI as the deterministic implementation and add a local `setup` step. `PROMPT.md` tells an agent how to inspect the target Mac, obtain approval for software/network changes, run setup, verify the chain, and report the exact Switch settings. `AGENTS.md` defines repository-wide safety and quality rules.

A prompt-only repository was rejected because agents could implement the same task differently on every Mac. Packaging a Homebrew formula or privileged system daemon was rejected as unnecessary for this MVP.

## Portable configuration

- Commit `config/nintendo-acc.env.example`, containing no machine-specific IP.
- Ignore `config/nintendo-acc.env`; generate it locally with `bin/nintendo-acc setup`.
- Detect the default network interface from the routing table and obtain its current IPv4 address with `ipconfig`.
- Validate that the detected listener is RFC1918 and never bind `0.0.0.0`, `::`, loopback, or a public address.
- Detect a reachable loopback Clash/Mihomo mixed, SOCKS5, or HTTP port from a small known candidate list. Never inspect or copy subscriptions, nodes, passwords, or tokens.
- Allow explicit environment overrides when automatic detection is ambiguous; fail with actionable instructions rather than guessing.

Example/test addresses may use documentation fixtures, but runtime documentation and committed configuration must never claim a fixed Mac IP.

## Runtime and sleep behavior

Run GOST as a per-login `launchctl` job. Wrap the GOST process with `/usr/bin/caffeinate -i` so that the display may turn off while idle system sleep is prevented for as long as the proxy job is alive. On Mac notebooks, closing the lid can still force sleep and is documented as unsupported unless macOS clamshell requirements are met.

The agent must report that the service is not a boot daemon: after logout or restart, the user runs `bin/nintendo-acc start` again.

## Repository contents

- `README.md`: human quick start, architecture, setup, Switch fields, sleep behavior, troubleshooting, security model.
- `PROMPT.md`: copy-paste prompt for a target-machine agent.
- `AGENTS.md`: canonical agent instructions automatically discovered by Codex-compatible tools.
- `bin/nintendo-acc`: setup and lifecycle CLI.
- `lib/nintendo_acc.sh`: validation, detection, config rendering, and launch argument helpers.
- `config/nintendo-acc.env.example`: portable, non-secret template.
- `tests/nintendo-acc-test.sh`: offline safety and behavior tests.
- `docs/plans/`: design and implementation rationale.

## Safety and publishing

- Runtime configuration and `.runtime/` are ignored.
- No proxy credentials, subscription URLs, local logs, PID files, or machine identifiers may be committed.
- Before publishing, run syntax checks, the full test suite, a secret scan, and a tracked-file review.
- Initialize `main`, create public GitHub repository `Miss-you/nintendo-acc`, push, and verify visibility plus remote file contents.

## Acceptance criteria

1. A clean checkout contains no actual LAN IP in runtime configuration.
2. `bin/nintendo-acc setup` generates a valid local configuration or stops with a precise corrective message.
3. `start` uses `launchctl` and `caffeinate -i`.
4. Tests cover address detection/config generation/safe binding/launch arguments and documentation contracts.
5. `PROMPT.md`, `AGENTS.md`, and `README.md` are mutually consistent.
6. The public GitHub repository is cloneable and contains only reviewed files.
