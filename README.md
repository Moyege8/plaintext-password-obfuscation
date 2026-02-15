# Plaintext Password Obfuscation

## Overview
A comprehensive solution for obfuscating plaintext passwords in configuration files.

## Background

This solution addresses a critical security requirement: securing plaintext passwords stored in application configuration files. Originally developed to solve password exposure in Bindplane's `config.yaml` file, this methodology is platform-agnostic and can be adapted for password obfuscation across various systems.

**Note:** Bindplane is an enterprise distribution of the open-source OpenTelemetry project.

## Implementation Versions

Two distinct versions have been developed and tested on Red Hat Enterprise Linux 9, each offering different approaches.

### Version 1: Interactive Vault Authentication

**Repository:** [Version 1 Folder](https://github.com/Moyege8/plaintext-password-obfuscation/tree/main/version-1) | [Version 1 README](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/version-1/README.md)

This implementation leverages Ansible Vault and Linux systemd to provide interactive password protection.

**Key Characteristics:**
- Prompts for vault key each time `systemctl start bindplane` is ran
- Immediately removes configuration file from filesystem after loading
- Requires operator presence during service restarts, including automated maintenance windows (e.g., midnight patching cycles)

**Best suited for:** Organizations where service restarts are infrequent and predictable.

### Version 2: Automated Credential Management

**Repository:** [Version 2 Folder](https://github.com/Moyege8/plaintext-password-obfuscation/tree/main/version-2) | [Version 2 README](https://github.com/Moyege8/plaintext-password-obfuscation/tree/main/version-2#readme)

This implementation combines Ansible Vault, Linux systemd, and systemd's `LoadCredentialEncrypted` feature to enable fully automated service startup.

**Key Characteristics:**
- Stores encrypted Ansible Vault decryption key locally on the host
- Automatically decrypts vault key at runtime via systemd's `LoadCredentialEncrypted`
- Generates `config.yaml` in memory during service initialization via `bindplane-config-manager_v2.sh`
- Immediately removes configuration file from filesystem after loading
- Ensures plaintext passwords never persist on disk

**Best suited for:** Production environments requiring automated deployments, unattended restarts, and scheduled maintenance operations.

## Security Model

Both versions prevent plaintext password exposure in configuration files. And additionally ensures that sensitive configuration data exists only transiently in system memory, never persisting to disk where it could be compromised through filesystem access or backup procedures.

## Repository Structure
```
plaintext-password-obfuscation/
├── README.md (this file)
├── common/                    # Shared configuration files
│   ├── bindplane-config.yml.j2
│   ├── deploy_bindplane.yml
│   └── inventory.ini
│
├── version-1/                 # Version 1 specific files
│    ├── README.md
│    ├── bindplane.service
│    └── bindplane-config-manager.sh
│  
└── version-2/                 # Version 2 specific files
    ├── README.md
    ├── bindplane.service
    └── bindplane-config-manager_v2.sh
```

**Shared Files:** Configuration files common to both versions are located in the [root directory](https://github.com/Moyege8/plaintext-password-obfuscation).

**Version-Specific Files:** Each version has its own directory containing unique configuration files and detailed implementation instructions.

## Getting Started

1. Review both version READMEs to determine which approach best fits your security requirements and operational constraints
2. Follow the step-by-step instructions in your chosen version's README
3. Adapt the configuration templates to your specific environment

## Requirements

- Red Hat Enterprise Linux 9 (tested platform; other Linux distributions may work with modifications)
- Ansible and Ansible Vault
- systemd
- Root or sudo access

## Use Cases

This solution is applicable to any scenario where:
- Configuration files contain plaintext passwords
- Automated deployments are required
- Security policies mandate password obfuscation
- Applications read configuration from YAML/text files at startup

## Contributing

Contributions and adaptations for additional platforms are welcome. Please submit pull requests with appropriate documentation and testing notes.

## License

[MIT]

## Author

Created by Oludolapo Lawrence

## Support

For issues or questions, please open an issue in the GitHub repository.
