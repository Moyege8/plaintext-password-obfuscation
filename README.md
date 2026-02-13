# Plaintext Password Obfuscation

## Overview

A comprehensive solution for obfuscating plaintext passwords in configuration files using Ansible Vault and systemd integration.

### Genesis

The team I had just joined had been trying to onboard Bindplane for a while but were faced with the dilemma of how to hide the plaintext passwords in Bindplane's `config.yaml` file. I came up with the method described below. Bindplane is a version of the open source OpenTelemetry.

The method described below, although implemented on Bindplane, can be used for password obfuscation on any platform.

### Version Notes

This is version 1 of my password obfuscation solution. You will be prompted to provide the vault key every time you run `systemctl start bindplane`. Some clients may prefer this solution. However, the drawback of manually supplying the vault key at Bindplane startup is that, for automated Linux patch installations, you will need to be present at odd hours (midnight) to provide the vault key.

The solution described here was implemented on Red Hat Linux release 9.

> **Note:** Version 2 of this solution uses systemd's `LoadCredentialEncrypted` to supply the vault key at startup.

---

## Part 1: Initial Setup

### Prerequisites

#### 1. Backup Configuration File

Create a backup copy of the `config.yaml` in a directory other than `/etc/bindplane`:

```bash
cp config.yaml config.yaml_`date "+%Y%m%d-%H%M%S"`
```

Or preferably on a very secure system or in GitHub.

> **Security Tip:** For added security, replace the passwords and secrets in `config.yaml` file with placeholders when backing up the config, and store the actual passwords and secrets in CyberArk or a password/secret manager of your choice.

#### 2. Install Ansible

Check if Ansible is installed:

```bash
ansible --version
```

If Ansible is not installed, run:

```bash
sudo dnf install ansible-core
```

#### 3. Verify Jinja2 Installation

Verify that jinja2 is installed with Ansible:

```bash
ansible --version | grep -i jinja
```

---

### Setup Directory Structure

Create the necessary directory structure:

```bash
cd /etc/bindplane
mkdir -p bindplane-config/templates
mkdir -p bindplane-config/vars
chmod -R 750 bindplane-config/templates
chmod -R 750 bindplane-config/vars
```

---

### Create Jinja2 Template

Create a Jinja2 file from the `config.yaml` file and store it in `bindplane-config/templates`:

```bash
cd /etc/bindplane    # if you are not currently in the directory
cp config.yaml bindplane-config/templates/bindplane-config.yml.j2
```

Replace the values you want to obfuscate with placeholder variables.

**Example placeholders:**
- `password: "{{bindplane_admin_password}}"`
- `sessionSecret: "{{bindplane_session_secret}}"`
- `password: "{{bindplane_postgres_password}}"`

Use your favorite editor to edit the file, then verify the `bindplane-config.yml.j2` is properly obfuscated:

```bash
grep "{{" bindplane-config.yml.j2
```

**Expected output:**
```
password: "{{bindplane_admin_password}}"
  sessionSecret: "{{bindplane_session_secret}}"
    password: "{{bindplane_postgres_password}}"
```

---

### Create Encrypted Secrets File

Using `ansible-vault`, create the secrets file in `/etc/bindplane/bindplane-config/vars`:

```bash
cd /etc/bindplane/bindplane-config/vars
ansible-vault create bindplane_secrets.yml
```

You will be prompted:

```
New Vault password: #Enter a strong password of your choice. Store this password in a safe place (CyberArk, for example).
Confirm New Vault password:
```

The file should look like this when done:

```yaml
bindplane_admin_password: "replace this with the actual password"
bindplane_session_secret: "replace this with the actual value"
bindplane_postgres_password: "replace this with the actual password"
```

If you check the content of the file, you would see that it is now encrypted and only you know the password for decrypting the secret file:

```bash
more bindplane_secrets.yml
```

---

### Create Ansible Deployment Playbook

Create the Ansible deploy file in `/etc/bindplane/bindplane-config/deploy_bindplane.yml`:

```yaml
---
- name: Deploy Bindplane Configuration with encrypted password
  hosts: localhost
  connection: local
  gather_facts: no
  vars_files:
    - vars/bindplane_secrets.yml

  tasks:
    - name: Ensure output directory exists
      file:
        path: ./output
        state: directory
        mode: '0700'

    - name: Generate config.yaml from template with decrypted passwords
      template:
        src: templates/bindplane-config.yml.j2
        dest: ./output/config.yaml
        mode: '0600'
```

---

### Create Ansible Inventory File

Create an Ansible inventory file in `/etc/bindplane/bindplane-config`:

```bash
vi inventory.ini
```

The content should look like this:

```ini
[local]
localhost ansible_connection=local
```

---

**✅ Part 1 is now complete**

---

## Part 2: Configuration Manager Script

### Overview

Copy the workhorse script `bindplane-config-manager.sh` to `/usr/local/bin` on the host where you are performing password obfuscation.

The script performs the following operations:
- Requests the vault key
- Uses the key to decrypt the encrypted passwords stored in `bindplane_secrets.yml`
- Generates the `config.yaml` using `ansible-playbook deploy_bindplane.yml` which in turn uses `bindplane-config.yml.j2`
- Cleans up all temp files

---

### Test the Script

Test that the script is running correctly from any directory:

#### Test Prepare Function

```bash
bindplane-config-manager.sh prepare
```

**Expected output:**

```
[INFO] Preparing Bindplane configuration...
[INFO] Prompting for vault password...
🔒 Enter Ansible Vault password for BindPlane: ****************
[INFO] Decrypting passwords and generating config...
[INFO] Deploying config to /etc/bindplane/config.yaml
[INFO] Config deployed successfully
```

#### Test Cleanup Function

```bash
bindplane-config-manager.sh cleanup
```

**Expected output:**

```
[WARNING] Cleaning up config file...
[INFO] Config file securely removed
```

---

**✅ Once the script is in place and running correctly, Part 2 is complete**

---

## Part 3: Systemd Integration

### Prologue

Part 3 involves using RHEL9's systemd startup process to run the `bindplane-config-manager.sh` script that you have set up above.

Before password obfuscation, when you start Bindplane by running:

```bash
systemctl status bindplane
```

You see the following:

```
o bindplane.service - Bindplane is an observability pipeline that gives you the ability to collect, refine, and ship metrics, logs, and traces to any destination.
    Loaded: loaded (**/usr/lib/systemd/system/bindplane.service**; enabled; preset: disabled)
    Active: inactive (dead) since Tue 2025-11-11 14:09:39 EST; 10s ago
  Duration: 4d 2min 5.187s
      Docs: https://bindplane.com/docs/getting-started/quickstart-guide
   Process: 2736162 ExecStart=/usr/local/bin/bindplane serve --config /etc/bindplane/config.yaml (code=exited, status=0/SUCCESS)
  Main PID: 2736162 (code=exited, status=0/SUCCESS)
       CPU: 2h 1min 17.745s
```

Observe that at Bindplane startup, systemd is loading `/usr/lib/systemd/system/bindplane.service`.

---

### Override Default Service File

We are going to override the Bindplane's loading of /usr/lib/systemd/system/bindplane.service and make systemd call our customized `bindplane.service` file that contains our `bindplane-config-manager.sh` script.

View the content of the default service file:

```bash
more /usr/lib/systemd/system/bindplane.service
```

Copy our customized `bindplane.service` to `/etc/systemd/system` on the Bindplane host where you are performing password obfuscation.

Check the content of the file to see how it is different from `/usr/lib/systemd/system/bindplane.service`.

When you run `systemctl`, it will now override `/usr/lib/systemd/system/bindplane.service` and take instructions from `/etc/systemd/system/bindplane.service`.

---

### Enable the Custom Service

To make systemctl start using `/etc/systemd/system/bindplane.service`:

```bash
systemctl daemon-reload
systemctl enable bindplane
systemctl start bindplane
```

Verify the service status:

```bash
systemctl status bindplane
```

**Expected output:**

```
● bindplane.service - BindPlane Server with Encrypted Configuration
    Loaded: loaded (/etc/systemd/system/bindplane.service; enabled; preset: disabled)
    Active: active (running) since Tue 2025-11-11 14:39:30 EST; 5s ago
      Docs: https://docs.bindplane.com
  Process: 3240468 ExecStartPre=/usr/local/bin/bindplane-config-manager.sh prepare (code=exited, status=0/SUCCESS)
  Process: 3240647 ExecStart=/usr/local/bin/bash -c sleep 15 && /usr/local/bin/bindplane-config-manager.sh cleanup & (code=exited, status=0/SUCCESS)
  Main PID: 3240646 (bindplane)
```

You can see that systemd is now loading `/etc/systemd/system/bindplane.service` at startup.

You would also see that the Bindplane's `config.yaml` is no longer visible in `/etc/bindplane`, creating an additional level of security.

---

**✅ The BindPlane password obfuscation process is now complete**

---

## Version Control

### Files to Commit to GitHub

Commit the following to GitHub or a repository of your choice:

```
bindplane-config/
├── deploy_bindplane.yml
├── inventory.ini
└── templates/
    └── bindplane-config.yml.j2
```

> **Security Note:** Do **NOT** commit the `vars/bindplane_secrets.yml` file to version control as it contains encrypted passwords.

---

## Maintenance Operations

### Update Passwords

If you change the passwords in Bindplane's `config.yaml` file, you will need to update the `bindplane_secrets.yml` file where the encrypted passwords are stored:

```bash
cd /etc/bindplane/bindplane-config/vars
ansible-vault edit bindplane_secrets.yml
```

You will be prompted for the vault password.

---

### Change Vault Password

To change the vault password:

```bash
cd /etc/bindplane/bindplane-config/vars
ansible-vault rekey bindplane_secrets.yml
```

You will be prompted for the current password and then prompted to provide a new password.

---

### Add LDAP Password

To update the `config.yaml` with LDAP:

1. Update the `/etc/bindplane/bindplane-config/templates/bindplane-config.yml.j2` file with LDAP password placeholder:

   ```yaml
   password: "{{bindplane_ldap_password}}"
   ```

2. Update the `bindplane_secrets.yml` file using the edit command described earlier:

   ```bash
   ansible-vault edit bindplane_secrets.yml
   ```

---

## Rollback Procedure

To roll back password obfuscation (i.e., for some reason you want to revert back to having plaintext credentials in Bindplane's `config.yaml` file):

### Step 1: Restore Original Config

Restore the most recent `config.yaml` that you backed up during the prerequisite section of this document to `/etc/bindplane`.

### Step 2: Remove Service Override

Remove the override in `/etc/systemd/system/bindplane.service` by renaming the file:

```bash
cd /etc/systemd/system
mv bindplane.service bindplane.service_`date "+%Y%m%d-%H%M%S"`
```

### Step 3: Reload and Restart

```bash
systemctl daemon-reload
systemctl enable bindplane
systemctl start bindplane
```

BindPlane will revert to loading `/usr/lib/systemd/system/bindplane.service` at startup, and the `config.yaml` will be present in `/etc/bindplane` with plaintext credentials.

> **Important:** This is why it is critical to store the `config.yaml` file backup in a secure manner.

---

**✅ The rollback is now complete**

---

## Security Considerations

1. **Backup Security**: Always store backups of `config.yaml` in a secure location (CyberArk, encrypted storage, or secure repository)
2. **Vault Password**: Store the Ansible Vault password in a secure password manager
3. **File Permissions**: Ensure proper file permissions on all configuration files (600 or 700)
4. **Version Control**: Never commit encrypted secrets to public repositories
5. **Temporary Files**: The script automatically cleans up temporary files containing decrypted passwords

---

## Troubleshooting

### Check Logs

View BindPlane deployment logs:

```bash
cat /var/log/bindplane-deploy.log
```

### Verify Service Status

```bash
systemctl status bindplane
journalctl -u bindplane -f
```

### Test Ansible Playbook Manually

```bash
cd /etc/bindplane/bindplane-config
ansible-playbook deploy_bindplane.yml --ask-vault-pass
```

---

## License

MIT License

## Author

**Olu Lawrence**  
Date: November 12, 2025

## Contributing

https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/contribution%20guidelines

---

## Additional Resources

- [BindPlane Documentation](https://docs.bindplane.com)
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)


