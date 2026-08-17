# Manual Start Checklist Design

## Goal

Create one local README that reminds the user how to manually start and verify the Nintendo proxy after restarting or logging in to the Mac.

## Chosen approach

Create `../开机启动服务列表/README.md` as a focused checklist for this service only. The checklist uses `~/Documents/Github/nintendo-acc` to enter the repository, then runs the existing CLI commands instead of duplicating lifecycle logic in a new script.

The README covers the complete manual flow: start the local Clash/Mihomo core, enter the repository, run `preflight`, start GOST, verify `status` and the HTTPS proxy chain, print the Switch settings, and stop the proxy when it is no longer needed.

## Safety and error handling

- Do not record subscriptions, credentials, node details, or local proxy configuration.
- Explain that `start` opens an unauthenticated proxy only on the configured RFC1918 address.
- Tell the user to stop if `preflight` reports that the Mac address or upstream port changed; use `setup --force` only after checking the current network.
- Keep automatic login or boot persistence out of scope.
- Preserve the existing `caffeinate -i` behavior while the manually started service runs.

## Verification

Verify that the local README exists, names the correct repository directory, includes the start/status/test/switch/stop commands, and contains no machine-specific IP address or credentials. Then deploy the current machine with the existing CLI and require fresh evidence from `preflight`, `status`, and `test` before reporting success.
