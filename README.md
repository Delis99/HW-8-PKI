# HW-8 — Public Key Infrastructure (PKI) and HTTPS Web Server Setup

## Project Overview

This project implements a complete Public Key Infrastructure (PKI) using OpenSSL and applies it to secure an Apache Tomcat web server via HTTPS on port **8443**.

The main tasks are:

- Creating a **Root Certificate Authority (CA)**
- Creating an **Intermediate CA**
- Generating a **server certificate** for Tomcat
- Packaging certificates into a **PKCS#12 (.p12)** keystore
- Configuring **Tomcat `server.xml`** for HTTPS
- Verifying a successful secure browser connection

This repository contains the OpenSSL configuration files and support scripts used to build the PKI.  
**Private keys and other sensitive files are intentionally excluded for security.**

---

## Repository Structure

```text
HW-8-PKI/
│
├── pki/
│   ├── openssl-root.cnf               # Root CA OpenSSL configuration
│   ├── openssl-intermediate.cnf       # Intermediate CA OpenSSL configuration
│   ├── scripts/
│   │   └── generate_pki.sh            # Optional automation script
│   └── .DS_Store                      # System file (not relevant to grading)
│
├── .gitignore                         # Protects private keys and sensitive files
└── README.md                          # This documentation

