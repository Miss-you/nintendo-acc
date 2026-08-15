#!/usr/bin/env bash

is_ipv4() {
  local address="$1"
  local first second third fourth octet

  if [[ ! "$address" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    return 1
  fi

  first="${BASH_REMATCH[1]}"
  second="${BASH_REMATCH[2]}"
  third="${BASH_REMATCH[3]}"
  fourth="${BASH_REMATCH[4]}"

  for octet in "$first" "$second" "$third" "$fourth"; do
    if (( 10#$octet > 255 )); then
      return 1
    fi
  done
}

is_private_ipv4() {
  local address="$1"
  local first second

  is_ipv4 "$address" || return 1
  IFS=. read -r first second _ _ <<< "$address"

  if (( 10#$first == 10 )); then
    return 0
  fi
  if (( 10#$first == 172 && 10#$second >= 16 && 10#$second <= 31 )); then
    return 0
  fi
  if (( 10#$first == 192 && 10#$second == 168 )); then
    return 0
  fi
  return 1
}

parse_default_interface() {
  awk '
    $1 == "interface:" {
      print $2
      found=1
      exit
    }
    END {
      if (!found) exit 1
    }
  '
}

detect_default_interface() {
  route -n get default 2>/dev/null | parse_default_interface
}

detect_interface_ipv4() {
  local interface_name="$1"
  ipconfig getifaddr "$interface_name" 2>/dev/null
}

port_is_open() {
  local host="$1"
  local port="$2"
  nc -z -w 2 "$host" "$port" >/dev/null 2>&1
}

detect_upstream_url() {
  local candidate scheme host port

  for candidate in \
    "socks5 127.0.0.1 7890" \
    "socks5 127.0.0.1 7898" \
    "http 127.0.0.1 7899"; do
    read -r scheme host port <<< "$candidate"
    if port_is_open "$host" "$port"; then
      printf '%s://%s:%s\n' "$scheme" "$host" "$port"
      return 0
    fi
  done
  return 1
}

render_config() {
  local interface_name="$1"
  local listen_host="$2"
  local listen_port="$3"
  local upstream_url="$4"

  printf 'LISTEN_INTERFACE=%s\n' "$interface_name"
  printf 'LISTEN_HOST=%s\n' "$listen_host"
  printf 'LISTEN_PORT=%s\n' "$listen_port"
  printf 'UPSTREAM_URL=%s\n' "$upstream_url"
  printf 'PROBE_URL=https://www.nintendo.com/robots.txt\n'
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  (( 10#$port >= 1 && 10#$port <= 65535 ))
}

parse_upstream_url() {
  local upstream_url="$1"

  if [[ ! "$upstream_url" =~ ^(http|https|socks5|socks5h)://([^/@]+@)?([^:/]+):([0-9]+)$ ]]; then
    return 1
  fi

  UPSTREAM_SCHEME="${BASH_REMATCH[1]}"
  UPSTREAM_HOST="${BASH_REMATCH[3]}"
  UPSTREAM_PORT="${BASH_REMATCH[4]}"
}

validate_config() {
  local listen_host="$1"
  local listen_port="$2"
  local upstream_url="$3"

  if ! is_private_ipv4 "$listen_host"; then
    printf 'LISTEN_HOST 必须是 RFC1918 私有 IPv4 地址，不能是通配、回环或公网地址。\n' >&2
    return 1
  fi
  if ! validate_port "$listen_port"; then
    printf 'LISTEN_PORT 必须是 1-65535 之间的整数。\n' >&2
    return 1
  fi
  if ! parse_upstream_url "$upstream_url"; then
    printf 'UPSTREAM_URL 必须是带端口的 http(s):// 或 socks5(h):// URL。\n' >&2
    return 1
  fi
  if [[ "$UPSTREAM_HOST" != "127.0.0.1" ]]; then
    printf 'UPSTREAM_URL 默认只允许指向 127.0.0.1。\n' >&2
    return 1
  fi
  if ! validate_port "$UPSTREAM_PORT"; then
    printf 'UPSTREAM_URL 的端口无效。\n' >&2
    return 1
  fi
}

redact_url() {
  local url="$1"
  if [[ "$url" =~ ^([^:]+://)([^/@]+)@(.+)$ ]]; then
    printf '%s***:***@%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}"
  else
    printf '%s\n' "$url"
  fi
}

build_gost_args() {
  GOST_ARGS=(
    -L "http://${LISTEN_HOST}:${LISTEN_PORT}"
    -F "$UPSTREAM_URL"
  )
}

build_launchctl_args() {
  local gost_bin="$1"
  local service_label="$2"
  local log_file="$3"

  build_gost_args
  LAUNCHCTL_ARGS=(
    submit
    -l "$service_label"
    -o "$log_file"
    -e "$log_file"
    --
    /usr/bin/caffeinate
    -i
    "$gost_bin"
    "${GOST_ARGS[@]}"
  )
}
