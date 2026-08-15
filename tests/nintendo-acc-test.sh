#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_FILE="$ROOT_DIR/lib/nintendo_acc.sh"
TESTS_RUN=0
TESTS_FAILED=0

pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  printf 'ok %d - %s\n' "$TESTS_RUN" "$1"
}

fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf 'not ok %d - %s\n' "$TESTS_RUN" "$1"
}

assert_success() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$description"
  else
    fail "$description"
  fi
}

assert_failure() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$description"
  else
    pass "$description"
  fi
}

assert_equals() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$description"
  else
    fail "$description (expected: $expected, actual: $actual)"
  fi
}

assert_contains() {
  local description="$1"
  local haystack="$2"
  local needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$description"
  else
    fail "$description (missing: $needle)"
  fi
}

if [[ ! -f "$LIB_FILE" ]]; then
  printf 'not ok 1 - library exists (%s)\n' "$LIB_FILE"
  exit 1
fi

# shellcheck source=../lib/nintendo_acc.sh
source "$LIB_FILE"

TEST_LISTEN_HOST="192.168.50.20"
TEST_LISTEN_PORT="18080"
TEST_UPSTREAM_URL="socks5://127.0.0.1:7890"

assert_success "accepts the intended private-LAN configuration" \
  validate_config "$TEST_LISTEN_HOST" "$TEST_LISTEN_PORT" "$TEST_UPSTREAM_URL"
assert_success "accepts a loopback HTTP upstream" \
  validate_config "10.0.0.20" "18080" "http://127.0.0.1:7899"
assert_failure "rejects a wildcard IPv4 listener" \
  validate_config "0.0.0.0" "18080" "socks5://127.0.0.1:7890"
assert_failure "rejects a wildcard IPv6 listener" \
  validate_config "::" "18080" "socks5://127.0.0.1:7890"
assert_failure "rejects a loopback listener" \
  validate_config "127.0.0.1" "18080" "socks5://127.0.0.1:7890"
assert_failure "rejects a public listener address" \
  validate_config "8.8.8.8" "18080" "socks5://127.0.0.1:7890"
assert_failure "rejects an invalid listening port" \
  validate_config "$TEST_LISTEN_HOST" "70000" "$TEST_UPSTREAM_URL"
assert_failure "rejects a non-loopback upstream" \
  validate_config "$TEST_LISTEN_HOST" "$TEST_LISTEN_PORT" "socks5://192.168.50.2:7890"
assert_failure "rejects an unsupported upstream scheme" \
  validate_config "$TEST_LISTEN_HOST" "$TEST_LISTEN_PORT" "ftp://127.0.0.1:7890"

LISTEN_HOST="$TEST_LISTEN_HOST"
LISTEN_PORT="$TEST_LISTEN_PORT"
UPSTREAM_URL="$TEST_UPSTREAM_URL"
build_gost_args
assert_equals "builds the HTTP listener" "http://${TEST_LISTEN_HOST}:${TEST_LISTEN_PORT}" "${GOST_ARGS[1]}"
assert_equals "builds the SOCKS5 forwarding chain" "$TEST_UPSTREAM_URL" "${GOST_ARGS[3]}"

if declare -F build_launchctl_args >/dev/null 2>&1; then
  build_launchctl_args "/opt/homebrew/bin/gost" "io.local.nintendo-acc" "/tmp/nintendo-acc.log"
  assert_equals "uses launchctl submit" "submit" "${LAUNCHCTL_ARGS[0]}"
  assert_equals "sets the launchctl service label" "io.local.nintendo-acc" "${LAUNCHCTL_ARGS[2]}"
  assert_equals "passes GOST as the managed executable" "/opt/homebrew/bin/gost" "${LAUNCHCTL_ARGS[8]}"
  assert_equals "preserves the listener in launchctl arguments" \
    "http://${TEST_LISTEN_HOST}:${TEST_LISTEN_PORT}" "${LAUNCHCTL_ARGS[10]}"
  assert_equals "preserves the upstream in launchctl arguments" \
    "$TEST_UPSTREAM_URL" "${LAUNCHCTL_ARGS[12]}"
else
  fail "launchctl argument builder exists"
fi

route_sample='   route to: default
destination: default
       mask: default
    gateway: 192.168.50.1
  interface: en7'
if declare -F parse_default_interface >/dev/null 2>&1; then
  detected_interface="$(printf '%s\n' "$route_sample" | parse_default_interface)"
  assert_equals "parses the default network interface" "en7" "$detected_interface"
else
  fail "default-interface parser exists"
fi

if declare -F render_config >/dev/null 2>&1; then
  rendered_config="$(render_config "en7" "$TEST_LISTEN_HOST" "$TEST_LISTEN_PORT" "$TEST_UPSTREAM_URL")"
  assert_contains "renders the detected interface" "$rendered_config" "LISTEN_INTERFACE=en7"
  assert_contains "renders the detected private address" "$rendered_config" "LISTEN_HOST=$TEST_LISTEN_HOST"
  assert_contains "renders the selected upstream" "$rendered_config" "UPSTREAM_URL=$TEST_UPSTREAM_URL"
else
  fail "local-config renderer exists"
fi

if declare -F detect_upstream_url >/dev/null 2>&1; then
  port_is_open() {
    [[ "$1" == "127.0.0.1" && "$2" == "7899" ]]
  }
  detected_upstream="$(detect_upstream_url)"
  assert_equals "selects a reachable loopback HTTP upstream" \
    "http://127.0.0.1:7899" "$detected_upstream"
  source "$LIB_FILE"
else
  fail "loopback-upstream detector exists"
fi

redacted="$(redact_url 'socks5://alice:secret@127.0.0.1:7890')"
assert_equals "redacts upstream credentials" "socks5://***:***@127.0.0.1:7890" "$redacted"

CLI_FILE="$ROOT_DIR/bin/nintendo-acc"
TEST_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP_DIR"' EXIT
CONFIG_FILE="$TEST_TMP_DIR/nintendo-acc.env"
printf 'LISTEN_INTERFACE=en7\nLISTEN_HOST=%s\nLISTEN_PORT=%s\nUPSTREAM_URL=%s\n' \
  "$TEST_LISTEN_HOST" "$TEST_LISTEN_PORT" "$TEST_UPSTREAM_URL" >"$CONFIG_FILE"
if [[ ! -x "$CLI_FILE" ]]; then
  fail "CLI exists and is executable"
else
  switch_output="$(NINTENDO_ACC_CONFIG="$CONFIG_FILE" "$CLI_FILE" switch 2>&1)"
  assert_contains "prints the Switch proxy server" "$switch_output" "服务器：$TEST_LISTEN_HOST"
  assert_contains "prints the Switch proxy port" "$switch_output" "端口：18080"
  assert_contains "disables Switch proxy authentication" "$switch_output" "认证：关闭"

  if NINTENDO_ACC_CONFIG="$CONFIG_FILE" "$CLI_FILE" unknown >/dev/null 2>&1; then
    fail "rejects an unknown command"
  else
    pass "rejects an unknown command"
  fi
fi

EXAMPLE_CONFIG="$ROOT_DIR/config/nintendo-acc.env.example"
if [[ ! -f "$EXAMPLE_CONFIG" ]]; then
  fail "portable config example exists"
else
  example_content="$(sed -n '1,120p' "$EXAMPLE_CONFIG")"
  assert_contains "leaves the example listener address empty" "$example_content" "LISTEN_HOST="
  if [[ "$example_content" == *"192.168.31.166"* ]]; then
    fail "does not publish the source Mac address"
  else
    pass "does not publish the source Mac address"
  fi
fi

if git -C "$ROOT_DIR" check-ignore -q config/nintendo-acc.env; then
  pass "ignores the generated local config"
else
  fail "ignores the generated local config"
fi

README_FILE="$ROOT_DIR/README.md"
if [[ ! -f "$README_FILE" ]]; then
  fail "README exists"
else
  readme_content="$(sed -n '1,260p' "$README_FILE")"
  assert_contains "documents GOST installation" "$readme_content" "brew install gost"
  assert_contains "documents Clash startup" "$readme_content" "Clash Verge"
  assert_contains "documents the start command" "$readme_content" "bin/nintendo-acc start"
  assert_contains "documents the Switch server address" "$readme_content" "192.168.31.166"
  assert_contains "documents Switch proxy authentication" "$readme_content" "认证"
  assert_contains "documents shutdown" "$readme_content" "bin/nintendo-acc stop"
fi

if (( TESTS_FAILED > 0 )); then
  printf '# %d of %d tests failed\n' "$TESTS_FAILED" "$TESTS_RUN"
  exit 1
fi

printf '# all %d tests passed\n' "$TESTS_RUN"
