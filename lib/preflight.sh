#!/usr/bin/env bash
set -Eeuo pipefail

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "ERROR: jalankan installer sebagai root." >&2
    exit 1
  fi
}

detect_supported_os() {
  [ -r /etc/os-release ] || { echo "ERROR: /etc/os-release tidak ditemukan." >&2; exit 1; }
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_VERSION_ID="${VERSION_ID:-}"
  case "$OS_ID:$OS_VERSION_ID" in
    debian:11|debian:12|debian:13|ubuntu:20.04|ubuntu:22.04|ubuntu:24.04|ubuntu:26.04) ;;
    *) echo "ERROR: OS tidak didukung: ${OS_ID:-unknown} ${OS_VERSION_ID:-unknown}" >&2; exit 1 ;;
  esac
  export OS_ID OS_VERSION_ID
}

detect_arch() {
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) ARCH_FAMILY="amd64" ;;
    aarch64|arm64) ARCH_FAMILY="arm64" ;;
    *) echo "ERROR: arsitektur tidak didukung: $ARCH" >&2; exit 1 ;;
  esac
  export ARCH ARCH_FAMILY
}

preflight() {
  require_root
  detect_supported_os
  detect_arch
}
