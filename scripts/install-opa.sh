#!/usr/bin/env bash
set -euo pipefail

version="1.18.2"
install_dir="${OPA_INSTALL_DIR:-.tools/bin}"
os="$(uname -s)"
arch="$(uname -m)"

case "${os}/${arch}" in
  Linux/x86_64)
    asset="opa_linux_amd64_static"
    checksum="9903e5125ac281104f2c4b7371d10cc3b74a98933743fcbfc174f9bf0ab20de8"
    ;;
  Darwin/arm64)
    asset="opa_darwin_arm64_static"
    checksum="3ffa2af6a3b9ccff5d171d061d27990db5ad8cc5c10214c7eeeabc0f29ca11cf"
    ;;
  *)
    echo "Unsupported OPA platform: ${os}/${arch}" >&2
    exit 1
    ;;
esac

mkdir -p "${install_dir}"
destination="${install_dir}/opa"

if [[ -x "${destination}" ]] && [[ "$("${destination}" version | awk '/Version:/ {print $2}')" == "${version}" ]]; then
  exit 0
fi

temporary_file="$(mktemp)"
trap 'rm -f "${temporary_file}"' EXIT

curl --fail --silent --show-error --location \
  "https://github.com/open-policy-agent/opa/releases/download/v${version}/${asset}" \
  --output "${temporary_file}"

actual_checksum="$(shasum -a 256 "${temporary_file}" | awk '{print $1}')"
if [[ "${actual_checksum}" != "${checksum}" ]]; then
  echo "OPA checksum verification failed" >&2
  exit 1
fi

install -m 0755 "${temporary_file}" "${destination}"
