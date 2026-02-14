```markdown
# Plaintext Password Obfuscation

## Overview
A comprehensive solution for obfuscating plaintext passwords in configuration files, with particular application to Bindplane and OpenTelemetry deployments.

## Background

This solution addresses a critical security challenge encountered during Bindplane onboarding: securing plaintext passwords stored in the `config.yaml` configuration file. While developed specifically for Bindplane (an enterprise distribution of OpenTelemetry), the methodology is platform-agnostic and can be adapted for password obfuscation across various systems.

## Implementation Versions

Two distinct versions have been developed and tested on Red Hat Enterprise Linux 9, each offering different trade-offs between security and operational convenience.

### Version 1: Interactive Vault Authentication

**Repository:** [Version 1](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/version-1)

This implementation leverages Ansible Vault and Linux systemd to provide interactive password protection.

**Key Characteristics:**
- Prompts for vault key on each `systemctl start bindplane` execution
- Provides maximum security through manual authentication
- Requires operator presence during service restarts, including automated maintenance windows (e.g., midnight patching cycles)

**Best suited for:** Organizations prioritizing security controls over automation, or environments where service restarts are infrequent and predictable.

### Version 2: Automated Credential Management

**Repository:** [Version 2](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/version-2)

This implementation combines Ansible Vault, Linux systemd, and systemd's `LoadCredentialEncrypted` feature to enable fully automated service startup.

**Key Characteristics:**
- Stores encrypted Ansible Vault decryption key locally on the host
- Automatically decrypts vault key at runtime via systemd's `LoadCredentialEncrypted`
- Generates `config.yaml` in memory during service initialization
- Immediately removes configuration file from filesystem after loading
- Ensures plaintext passwords never persist on disk

**Best suited for:** Production environments requiring automated deployments, unattended restarts, and scheduled maintenance operations.

## Security Model

Both versions prevent plaintext password exposure in configuration files. Version 2 additionally ensures that sensitive configuration data exists only transiently in system memory, never persisting to disk where it could be compromised through filesystem access or backup procedures.

## Requirements

- Red Hat Enterprise Linux 9 (tested platform)
- Ansible Vault
- systemd

## Usage

### Starting the Bindplane Service

```bash
systemctl start bindplane
```

### Checking Service Status

```bash
systemctl status bindplane
```

### Stopping the Service

```bash
systemctl stop bindplane
```

## File References

- **Configuration File:** `config.yaml` (Bindplane configuration)
- **Vault Key Storage:** Encrypted credential stored via systemd (Version 2 only)

## Contributing

Contributions and adaptations for additional platforms are welcome. Please submit pull requests with appropriate documentation.

## License

[Specify your license here]

## Support

For issues or questions, please open an issue in the GitHub repository.
```
