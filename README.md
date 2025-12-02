
Assignment: HW-8 — Public Key Infrastructure (PKI) and HTTPS Web Server Setup

🔐 Project Overview

This project implements a complete Public Key Infrastructure (PKI) from scratch and uses it to secure an Apache Tomcat web server via HTTPS on port 8443.
The workflow includes:

Creating a Root Certificate Authority (CA)

Creating an Intermediate CA

Generating a server certificate for Tomcat

Packaging the certificate and private key into a PKCS#12 (.p12) keystore

Configuring Tomcat’s server.xml to enable HTTPS

Demonstrating a successful secure connection in a web browser

This repository contains the OpenSSL configuration files and supporting scripts used to build the PKI.
👉 Private keys are not included and are intentionally excluded for security.

📁 Repository Structure
HW-8-PKI/
│
├── pki/
│   ├── openssl-root.cnf             # Root CA OpenSSL configuration
│   ├── openssl-intermediate.cnf     # Intermediate CA OpenSSL configuration
│   ├── scripts/
│   │   └── generate_pki.sh          # Automation script (optional)
│   └── .DS_Store                    # macOS system file (ignored in grading)
│
├── .gitignore                       # Protects private keys and sensitive files
└── README.md                        # This documentation

🔒 Security Notes

This repository does NOT include:

Root CA private key

Intermediate CA private key

Server private key

PKCS#12 keystore

OpenSSL index/serial databases

These files should never be included in public repositories.
They are excluded via .gitignore following PKI best practices.

⚙️ PKI Workflow Summary
1. Create Root CA

Initialize required directories

Generate Root CA key + CSR

Self-sign the Root CA certificate

2. Create Intermediate CA

Generate key + CSR

Sign with Root CA

Produce Intermediate CA certificate

Build chain file (Root + Intermediate)

3. Generate Server Certificate

Create server key + CSR

Sign with Intermediate CA using correct extensions

4. Package for Tomcat

A .p12 keystore was created:

openssl pkcs12 -export \
  -name tomcat \
  -in server.crt \
  -inkey server.key \
  -certfile ca-chain.cert.pem \
  -out tomcat.p12

5. Configure Tomcat

conf/server.xml updated with:

<Connector
   protocol="org.apache.coyote.http11.Http11NioProtocol"
   port="8443" maxThreads="200"
   scheme="https" secure="true" SSLEnabled="true"
   keystoreFile="conf/tomcat.p12"
   keystoreType="PKCS12"
   keystorePass="changeit"
   keyAlias="tomcat"
   sslProtocol="TLS" />

6. Test HTTPS

Tomcat started successfully

Browser connected to:
https://localhost:8443

Certificate recognized as valid (trusted because the Root CA was imported into browser trust store)

🖼️ Screenshots (Provided in Word Report)

The Word report submitted with this assignment includes:

Root CA creation output

Intermediate CA creation output

Server certificate issuance

PKCS#12 bundle creation

Tomcat server.xml SSL configuration

Browser screenshot showing HTTPS lock icon

Tomcat homepage served securely over port 8443

Screenshots are not included in this repository per assignment instructions.

📌 How to Run Tomcat with HTTPS

From the apache-tomcat-7.0.109/bin directory:

chmod +x *.sh
./startup.sh


Then open:

👉 https://localhost:8443

If the Root CA was imported into your browser’s trust store, HTTPS will show as secure.

🔗 GitHub Repository Link

This repository is public to ensure the grader can access it:

🔗 https://github.com/Delis99/HW-8-PKI

🧑‍🏫 Notes for Grader

All private keys were intentionally excluded for security.

Complete documentation and screenshots are included in the submitted Word report.

This repository contains only the configuration files and scripts required by the assignment.

✔️ Status

Completed Successfully
Tomcat is running over HTTPS using a custom PKI certificate chain.
