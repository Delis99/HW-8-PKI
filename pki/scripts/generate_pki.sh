#!/usr/bin/env bash
set -euo pipefail

# This script builds a small PKI hierarchy modeled after
# https://pki-tutorial.readthedocs.io/en/latest/simple/ with:
#   - Offline root CA
#   - Online signing (intermediate) CA
#   - Server/TLS certificate for the supplied domain
# Passphrases can be supplied through environment variables to avoid prompts.

ROOT_PASS="${ROOT_CA_PASS:-changeit-root}"
INT_PASS="${INT_CA_PASS:-changeit-intermediate}"
SERVER_KEY_PASS="${SERVER_KEY_PASS:-}"
PKCS12_PASS="${SERVER_KEYSTORE_PASS:-changeit}"
DOMAIN="${1:-demo.local}"
OPENSSL_BIN="${OPENSSL_BIN:-openssl}"

ROOT_DIR="pki/root"
INT_DIR="pki/intermediate"
SERVER_DIR="pki/server/${DOMAIN}"
CHAIN_FILE="${INT_DIR}/certs/ca-chain.cert.pem"

msg() {
  printf "\n[%s] %s\n" "$(date +%H:%M:%S)" "$*"
}

ensure_ca_layout() {
  local dir="$1"
  mkdir -p "${dir}/certs" "${dir}/crl" "${dir}/csr" "${dir}/newcerts" "${dir}/private"
  chmod 700 "${dir}/private"
  touch "${dir}/index.txt"
  [[ -f "${dir}/serial" ]] || echo 1000 > "${dir}/serial"
  [[ -f "${dir}/crlnumber" ]] || echo 1000 > "${dir}/crlnumber"
}

ensure_server_layout() {
  local dir="$1"
  mkdir -p "${dir}/certs" "${dir}/csr" "${dir}/private"
}

generate_root() {
  ensure_ca_layout "${ROOT_DIR}"

  if [[ ! -f "${ROOT_DIR}/private/ca.key.pem" ]]; then
    msg "Generating encrypted root key"
    "${OPENSSL_BIN}" genrsa -aes256 -passout pass:"${ROOT_PASS}" \
      -out "${ROOT_DIR}/private/ca.key.pem" 4096
    chmod 400 "${ROOT_DIR}/private/ca.key.pem"
  else
    msg "Root key already exists, skipping"
  fi

  if [[ ! -f "${ROOT_DIR}/certs/ca.cert.pem" ]]; then
    msg "Issuing self-signed root certificate"
    "${OPENSSL_BIN}" req -config pki/openssl-root.cnf \
      -key "${ROOT_DIR}/private/ca.key.pem" \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out "${ROOT_DIR}/certs/ca.cert.pem" \
      -passin pass:"${ROOT_PASS}" \
      -subj "/C=US/O=HW-8 Security/OU=Root CA/CN=HW-8 Root CA"
    chmod 444 "${ROOT_DIR}/certs/ca.cert.pem"
  else
    msg "Root certificate already exists, skipping"
  fi
}

generate_intermediate() {
  ensure_ca_layout "${INT_DIR}"

  if [[ ! -f "${INT_DIR}/private/intermediate.key.pem" ]]; then
    msg "Generating encrypted intermediate key"
    "${OPENSSL_BIN}" genrsa -aes256 -passout pass:"${INT_PASS}" \
      -out "${INT_DIR}/private/intermediate.key.pem" 4096
    chmod 400 "${INT_DIR}/private/intermediate.key.pem"
  else
    msg "Intermediate key already exists, skipping"
  fi

  if [[ ! -f "${INT_DIR}/csr/intermediate.csr.pem" ]]; then
    msg "Creating intermediate CSR"
    "${OPENSSL_BIN}" req -config pki/openssl-intermediate.cnf -new -sha256 \
      -key "${INT_DIR}/private/intermediate.key.pem" \
      -out "${INT_DIR}/csr/intermediate.csr.pem" \
      -passin pass:"${INT_PASS}" \
      -subj "/C=US/O=HW-8 Security/OU=Signing CA/CN=HW-8 Signing CA"
  fi

  if [[ ! -f "${INT_DIR}/certs/intermediate.cert.pem" ]]; then
    msg "Signing intermediate certificate with the root CA"
    "${OPENSSL_BIN}" ca -config pki/openssl-root.cnf -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in "${INT_DIR}/csr/intermediate.csr.pem" \
      -out "${INT_DIR}/certs/intermediate.cert.pem" \
      -passin pass:"${ROOT_PASS}" -batch
    chmod 444 "${INT_DIR}/certs/intermediate.cert.pem"
  else
    msg "Intermediate certificate already exists, skipping"
  fi

  msg "Building CA chain"
  cat "${INT_DIR}/certs/intermediate.cert.pem" "${ROOT_DIR}/certs/ca.cert.pem" \
    > "${CHAIN_FILE}.tmp"
  mv -f "${CHAIN_FILE}.tmp" "${CHAIN_FILE}"
  chmod 444 "${CHAIN_FILE}"
}

generate_server_cert() {
  local domain="$1"
  ensure_server_layout "${SERVER_DIR}"

  if [[ ! -f "${SERVER_DIR}/private/${domain}.key.pem" ]]; then
    msg "Generating server key for ${domain}"
    if [[ -n "${SERVER_KEY_PASS}" ]]; then
      "${OPENSSL_BIN}" genrsa -aes256 -passout pass:"${SERVER_KEY_PASS}" \
        -out "${SERVER_DIR}/private/${domain}.key.pem" 2048
    else
      "${OPENSSL_BIN}" genrsa -out "${SERVER_DIR}/private/${domain}.key.pem" 2048
    fi
    chmod 400 "${SERVER_DIR}/private/${domain}.key.pem"
  else
    msg "Server key already exists, skipping"
  fi

  local server_cfg="${SERVER_DIR}/${domain}.cnf"
  cat > "${server_cfg}" <<EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = US
ST = ExampleState
L = ExampleCity
O = HW-8 Security
OU = Demo Server
CN = ${domain}

[ req_ext ]
subjectAltName = ${SERVER_ALT_NAMES:-DNS:${domain}}
EOF

  if [[ ! -f "${SERVER_DIR}/csr/${domain}.csr.pem" ]]; then
    msg "Creating CSR for ${domain}"
    if [[ -n "${SERVER_KEY_PASS}" ]]; then
      "${OPENSSL_BIN}" req -config "${server_cfg}" -key "${SERVER_DIR}/private/${domain}.key.pem" \
        -new -sha256 -out "${SERVER_DIR}/csr/${domain}.csr.pem" \
        -passin pass:"${SERVER_KEY_PASS}"
    else
      "${OPENSSL_BIN}" req -config "${server_cfg}" -key "${SERVER_DIR}/private/${domain}.key.pem" \
        -new -sha256 -out "${SERVER_DIR}/csr/${domain}.csr.pem"
    fi
  else
    msg "Server CSR already exists, skipping"
  fi

  if [[ ! -f "${SERVER_DIR}/certs/${domain}.cert.pem" ]]; then
    msg "Signing server certificate with intermediate CA"
    "${OPENSSL_BIN}" ca -config pki/openssl-intermediate.cnf \
      -extensions server_cert -days 825 -notext -md sha256 \
      -in "${SERVER_DIR}/csr/${domain}.csr.pem" \
      -out "${SERVER_DIR}/certs/${domain}.cert.pem" \
      -passin pass:"${INT_PASS}" -batch
    chmod 444 "${SERVER_DIR}/certs/${domain}.cert.pem"
  else
    msg "Server certificate already exists, skipping"
  fi

  msg "Exporting PKCS#12 bundle for Tomcat (${domain})"
  if [[ -n "${SERVER_KEY_PASS}" ]]; then
    "${OPENSSL_BIN}" pkcs12 -export \
      -in "${SERVER_DIR}/certs/${domain}.cert.pem" \
      -inkey "${SERVER_DIR}/private/${domain}.key.pem" \
      -passin pass:"${SERVER_KEY_PASS}" \
      -certfile "${CHAIN_FILE}" \
      -out "${SERVER_DIR}/${domain}.p12" \
      -passout pass:"${PKCS12_PASS}"
  else
    "${OPENSSL_BIN}" pkcs12 -export \
      -in "${SERVER_DIR}/certs/${domain}.cert.pem" \
      -inkey "${SERVER_DIR}/private/${domain}.key.pem" \
      -certfile "${CHAIN_FILE}" \
      -out "${SERVER_DIR}/${domain}.p12" \
      -passout pass:"${PKCS12_PASS}"
  fi
}

generate_root
generate_intermediate
generate_server_cert "${DOMAIN}"

msg "All artifacts ready under pki/"
