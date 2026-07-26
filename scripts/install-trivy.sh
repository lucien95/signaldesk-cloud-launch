#!/usr/bin/env bash
set -euo pipefail

version="0.72.0"
install_dir="${TRIVY_INSTALL_DIR:-.tools/bin}"
os="$(uname -s)"
arch="$(uname -m)"

case "${os}/${arch}" in
  Linux/x86_64)
    asset="trivy_${version}_Linux-64bit.tar.gz"
    checksum="bbb64b9695866ce4a7a8f5c9592002c5961cab378577fa3f8a040df362b9b2ea"
    ;;
  Darwin/arm64)
    asset="trivy_${version}_macOS-ARM64.tar.gz"
    checksum="88f208680dc05da2b459e19b4f5aa2b4dc7c2117892ba4aab2ae63baba330016"
    ;;
  *)
    echo "Unsupported Trivy platform: ${os}/${arch}" >&2
    exit 1
    ;;
esac

mkdir -p "${install_dir}"
destination="${install_dir}/trivy"

if [[ -x "${destination}" ]] && [[ "$("${destination}" --version | awk '/Version:/ {print $2}')" == "${version}" ]]; then
  exit 0
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "${temporary_dir}"' EXIT
archive="${temporary_dir}/${asset}"

curl --fail --silent --show-error --location \
  "https://github.com/aquasecurity/trivy/releases/download/v${version}/${asset}" \
  --output "${archive}"

actual_checksum="$(shasum -a 256 "${archive}" | awk '{print $1}')"
if [[ "${actual_checksum}" != "${checksum}" ]]; then
  echo "Trivy checksum verification failed" >&2
  exit 1
fi

tar -xzf "${archive}" -C "${temporary_dir}" trivy
install -m 0755 "${temporary_dir}/trivy" "${destination}"
