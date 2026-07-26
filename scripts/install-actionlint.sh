#!/usr/bin/env bash
set -euo pipefail

version="1.7.12"
install_dir="${ACTIONLINT_INSTALL_DIR:-.tools/bin}"
os="$(uname -s)"
arch="$(uname -m)"

case "${os}/${arch}" in
  Linux/x86_64)
    asset="actionlint_${version}_linux_amd64.tar.gz"
    checksum="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"
    ;;
  Darwin/arm64)
    asset="actionlint_${version}_darwin_arm64.tar.gz"
    checksum="aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f"
    ;;
  *)
    echo "Unsupported actionlint platform: ${os}/${arch}" >&2
    exit 1
    ;;
esac

mkdir -p "${install_dir}"
destination="${install_dir}/actionlint"

if [[ -x "${destination}" ]] && [[ "$("${destination}" -version)" == "${version}" ]]; then
  exit 0
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "${temporary_dir}"' EXIT
archive="${temporary_dir}/${asset}"

curl --fail --silent --show-error --location \
  "https://github.com/rhysd/actionlint/releases/download/v${version}/${asset}" \
  --output "${archive}"

actual_checksum="$(shasum -a 256 "${archive}" | awk '{print $1}')"
if [[ "${actual_checksum}" != "${checksum}" ]]; then
  echo "actionlint checksum verification failed" >&2
  exit 1
fi

tar -xzf "${archive}" -C "${temporary_dir}" actionlint
install -m 0755 "${temporary_dir}/actionlint" "${destination}"
