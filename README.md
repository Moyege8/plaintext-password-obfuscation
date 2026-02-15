# Plaintext Password Obfuscation

## Overview

A comprehensive solution for obfuscating plaintext passwords in configuration files.

### Genesis

The team I had joined had been trying to onboard Bindplane for a while but were faced with the dilemma of how to hide the plaintext passwords in Bindplane's `config.yaml` file. I came up with the method described below. Bindplane is a version of the open source OpenTelemetry.

The method described below, although implemented on Bindplane, can be used for password obfuscation on any platform.

### Version Notes

I have created two versions of the plaintext password obfuscation solution. Both solutions were implemented on Red Hat Linux release 9.
Version 1 uses ansible vault and Linux Systemd. In this version, you will be prompted to provide the vault key every time you run `systemctl start bindplane`. Some clients may like this option. 
However, manually supplying the vault key at Bindplane startup implies that, for automated Linux patch installations, you will need to be present at odd hours (midnight) to manually input the vault key at Systemd startup prompt.

Version 2 relies on ansible vault, Linux Systemd and Systemd's LoadCredentialEncypted. In this version, the ansible vault secret decryption key is stored on the local host, encrypted. 
At bindplane startup i.e. when `systemctl start bindplane` is ran, systemd's `LoadCredentialEncrypted` decrypts the ansible vault key at runtime and supplies the vault key to the bindplane-config-manager.sh script that generates bindplane's config.yml file.

Immediately the config.yml is created and stored in system memory, bindplane-config-manager.sh deletes the config.yaml from the file system.
This way the config.yml file containing plaintext password is not visible in the file system.

For version 1 see:
[Version 1 Readme](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/version-1/README.md) for the procedure.
and [Version 1 folder](https://github.com/Moyege8/plaintext-password-obfuscation/tree/main/version-1) for the config files.

Version 2 is work in progress.
https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/version-2
