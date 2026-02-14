Password Obfuscation Engine
A secure methodology for eliminating plaintext credentials in configuration files, specifically optimized for BindPlane (OpenTelemetry) environments on RHEL 9.
🛡️ Overview
Hardcoded passwords in config.yaml files represent a significant security risk. This project provides a robust framework to obfuscate these credentials using Ansible Vault and Linux Systemd, ensuring that sensitive data remains encrypted at rest and protected during runtime.
While designed for BindPlane, this logic is platform-agnostic and can be adapted for any service requiring secure configuration management.
🚀 Implementation Strategies
This repository offers two architectural approaches based on your organization's security and automation requirements.
Option 1: Manual Vault Decryption
Mechanism: Uses Ansible Vault integrated with systemd service units.
Workflow: Requires manual entry of the Vault password upon executing systemctl start bindplane.
Best Use Case: High-security environments where human intervention is required for every service restart to prevent unauthorized automated startups.
Option 2: Automated Runtime Decryption (Recommended)
Mechanism: Leverages Systemd’s LoadCredentialEncrypted and Ansible Vault.
Workflow:
The Ansible Vault decryption key is stored on the host in an encrypted state.
At service startup, systemd decrypts the key in memory.
A startup script generates the config.yaml using the decrypted secrets.
Volatile Storage: The configuration is held in system memory; the file is immediately purged from the physical filesystem to prevent "data at rest" exposure.
Best Use Case: Enterprise environments requiring automated patch management and high availability without manual intervention at odd hours.
🛠️ Technical Stack
Operating System: Red Hat Enterprise Linux (RHEL) 9
Security: Ansible Vault
Service Manager: Systemd (specifically LoadCredentialEncrypted)
Target Application: BindPlane / OpenTelemetry Collector
📁 Repository Structure
/version-1: Implementation guide for Manual Decryption.
/version-2: Implementation guide for Automated Runtime Decryption.
🤝 Contributing
Contributions to enhance the security logic or port these scripts to other distributions are welcome. Please open an issue or submit a pull request.
📜 License
Distributed under the MIT License.
