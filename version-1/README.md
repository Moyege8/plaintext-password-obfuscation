## Table of Contents

* [Prerequisites](#prerequisites)
* [Part 1 - Prepare the ansible files and create the directory structure and encrypt the passwords](#part-1---prepare-the-ansible-files-and-create-the-directory-structure-and-encrypt-the-passwords)
* [Part 2 - Deploy bindplane-config-manager.sh script that decrypts the passwords at Bindplane startup and creates the config.yaml file](#part-2---deploy-bindplane-config-managersh-script-that-decrypts-the-passwords-at-bindplane-startup-and-creates-the-configyaml-file)
* [Part 3 - Use Linux systemd startup process to run bindplane-config-manager.sh](#part-3---use-linux-systemd-startup-process-to-run-bindplane-config-managersh)
* [If you change the passwords in config.yaml](#if-you-change-the-passwords-in-configyaml)
* [To change the vault password](#to-change-the-vault-password)
* [To update the config.yaml with ldap](#to-update-the-configyaml-with-ldap)
* [To roll back Password obfuscation](#to-roll-back-password-obfuscation)
* [Security Considerations](#security-considerations)
* [Troubleshooting](#troubleshooting)
* [Check logs](#check-logs)

## Overview

Although this procedure was developed for Bindplane, it is applicable for all plaintext password obfuscations.

Password obfuscation version is a 3-part process, namely:

1. Prepare the ansible files and create the directory structure and encrypt the passwords.

2. Deploy bindplane-config-manager.sh script that decrypts the passwords at Bindplane startup and creates the config.yaml file.

3. Use Linux systemd startup process to run bindplane-config-manager.sh.

## Prerequisites
1. Create a backup copy of the config.yaml in a directory other than /etc/bindplane or preferably in GitHub.

2. Ensure ansible is installed.

```bash
ansible --version
```

If ansible is not installed,
run

```bash
sudo dnf install ansible-core
```

3. Verify that jinja2 is installed with ansible

```bash
ansible --version | grep -i jinja
```

## Part 1 - Prepare the ansible files and create the directory structure and encrypt the passwords.

1. Create the following directory structure as shown below:

```bash
cd /etc/bindplane
mkdir -p bindplane-config/templates
mkdir -p bindplane-config/vars

chmod -R 750 bindplane-config/templates
chmod -R 750 bindplane-config/vars
```

2. Create a jinja2 file from the config.yaml and store it in bindplane-config/templates
Sample [config.yaml](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/config.yaml) file 
Copy the config.yaml file to bindplane-config/templates/bindplane-config.yml.j2

```bash
cd /etc/bindplane    # if you are not currently in /etc/bindplane directory
cp config.yaml bindplane-config/templates/bindplane-config.yml.j2
```

3. Using your favorite editor, replace the values you want to obfuscate with placeholder variables.
Sample [bindplane-config.yml.j2](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/bindplane-config.yml.j2)

4. On the above-mentioned host, you can also run the grep command below to see the values that were obfuscated.
```bash
grep "{{" bindplane-config.yml.j2
```

5. Using ansible-vault create the secrets files in /etc/bindplane/bindplane-config/vars
```bash
cd /etc/bindplane/bindplane-config/vars

ansible-vault create bindplane_secrets.yml
```

New Vault password:    #Enter a strong password of your choice. Store this password in a safe place. Cyberark for example.
Confirm New Vault password:

Using the sample config.yaml and bindplane-config.yml.j2 mentioned above as an example, the bindplane_secrets.yml file should look something like this when done:
database_username: "replace this with the actual username"
database_password: "replace this with the actual password"
ldap_bind_password: "replace this with the actual password"
prometheus_username: "replace this with the actual username"
prometheus_password: "replace this with the actual password"
mysql_username: "replace this with the actual username"
mysql_password: "replace this with the actual password"
apache_ssh_username: "replace this with the actual username"
apache_ssh_password: "replace this with the actual password"
kafka_username: "replace this with the actual username"
kafka_password: "replace this with the actual password"
redis_password: "replace this with the actual password"
splunk_hec_token: "replace this with the actual value"
s3_access_key_id: "replace this with the actual value"

The save the file using vi editor's x! or wq!

If you check the content of the bindplane_secrets.yml file, you will see that it is now encrypted and only you know the password for decrypting the secret file.
Run the command below to see:
```bash
more bindplane_secrets.yml
```

6. Create the ansible deploy file in /etc/bindplane/bindplane-config/deploy_bindplane.yml
See example [deploy_bindplane.yml](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/deploy_bindplane.yml)
It should look like this
```yaml
---
- name: Deploy Bindplane Configuration with encrypted password
  hosts: localhost
  vars_files:
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

7. Create an ansible inventory file in /etc/bindplane/bindplane-config
```bash
vi inventory.ini
```
The file should look like this when ready [inventory.ini](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/inventory.ini)

bindplane-config directory and file structure should look like this when ready:


<img width="380" height="161" alt="image" src="https://github.com/user-attachments/assets/b92ec2e7-b898-4342-9e0b-0b138723e2fb" />




---------------------------------Part 1 is now complete--------------------------

## Part 2 - Deploy bindplane-config-manager.sh script that decrypts the passwords at Bindplane startup and creates the config.yaml file.

1. Copy [bindplane-config-manager.sh](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/version-1/bindplane-config-manager.sh) to /usr/local/bin on the host on which you are password obfuscating.

Make sure the permission looks as follows:
-rwxr-x---. 1 root root    3607 Feb 11 11:09 bindplane-config-manager_v2.sh

The workhorse script /usr/local/bin/bindplane-config-manager.sh, when ran, requests the vault_key and uses the key to decrypt the encrypted passwords stored in bindplane_secrets.yml.
It generates the config.yaml using ansible-playbook deploy_bindplane.yml file which in turn uses the bindplane-config.yml.j2 template
It cleans up all the temp files used in the process.

2. You can run the script manually to see how it behaves.
```bash
bindplane-config-manager_v2.sh prepare
```

**Prologue**

When you check the status of Bindplane by running the command
```bash
systemctl status bindplane
```

You see the following
○ bindplane.service - Bindplane is an observability pipeline that gives you the ability to collect, refine, and ship metrics, logs, and traces to any destination.
    Loaded: loaded (/usr/lib/systemd/system/bindplane.service; enabled; preset: disabled)
    Active: inactive (dead) since Tue 2025-08-12 15:07:35 EST; 10s ago
    Duration: 4d 2min 5.187s
      Docs: https://bindplane.com/docs/getting-started/quickstart-guide
    Process: 2736162 ExecStart=/usr/local/bin/bindplane serve --config /etc/bindplane/config.yaml (code=exited, status=0/SUCCESS)
  Main PID: 2736162 (code=exited, status=0/SUCCESS)
      CPU: 2h 1min 17.745s

Run the command below to see the content of the bindplane.service file.
```bash
more /usr/lib/systemd/system/bindplane.service
```

In Part 3, we are going to override bindplane service load path **/usr/lib/systemd/system/bindplane.service.**

-----once the script is in place and running correctly, part 2 is complete-----------------------

## Part 3 - Use Linux systemd startup process to run bindplane-config-manager_v2.sh

1. Copy [bindplane.service](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/version-1/bindplane.service) file which systemd will call at startup to /etc/systemd/system
on the Bindplane host on which you are password obfuscating.

Ensure the permission and ownership looks like this:

-rw-r----. 1 root    root    1479 Aug 12 15:02 bindplane.service

Check the content of the file to see how it is different from the one in /usr/lib/systemd/system/bindplane.service
When you run systemctl it will now override /usr/lib/systemd/system/bindplane.service and take instructions from /etc/systemd/system/bindplane.service

2. To make systemctl now start using /etc/systemd/system/bindplane.service
do
```bash
systemctl daemon-reload
systemctl enable bindplane
systemctl start bindplane
```

3. Run the command below to see the status of Bindplane
```bash
systemctl status bindplane
```

You would see that Bindplane is now using /etc/systemd/system/bindplane.service
● bindplane.service - BindPlane Server with Encrypted Configuration
    Loaded: loaded (/etc/systemd/system/bindplane.service; enabled; preset: disabled)
    Active: active (running) since Tue 2025-11-11 14:39:30 EST; 5s ago
      Docs: https://docs.bindplane.com
    Process: 3240468 ExecStartPre=/usr/local/bin/bindplane-config-manager.sh prepare (code=exited, status=0/SUCCESS)
    Process: 3240647 ExecStartPost=/bin/bash -c sleep 15 && /usr/local/bin/bindplane-config-manager.sh cleanup & (code=exited, status=0/SUCCESS)
  Main PID: 3240646 (bindplane)

You would also see that the bindplane's config.yaml is no longer visible in /etc/bindplane, creating an additional level of security.

-----------Bindplane password obfuscation process is now complete---------------------

## If you change the passwords in config.yaml

do

```bash
cd /etc/bindplane/bindplane-config/vars
ansible-vault edit bindplane_secrets.yml
```

You would be prompted for the vault password

## To change the vault password

do
```bash
cd /etc/bindplane/bindplane-config/vars
ansible-vault rekey bindplane_secrets.yml
```

You would be prompted for the current password and prompted to provide a new password

## To update the the config.yaml with ldap

Update the /etc/bindplane/bindplane-config/templates/bindplane-config.yml.j2 file with ldap password placeholder
e.g. password: "{{bindplane_ldap_password}}"

Update the bindplane_secrets.yml file by using the edit command described earlier
```bash
ansible-vault edit bindplane_secrets.yml
```

## To roll back Password obfuscation

1. Restore the most current config.yaml to /etc/bindplane

2. Remove the override in /etc/systemd/system/bindplane.service by renaming the file
```bash
cd /etc/systemd/system
mv bindplane.service bindplane.service_`date "+%Y%m%d-%H%M%S"`
```

3. Do
```bash
systemctl daemon-reload
systemctl enable bindplane
```

Bindplane will now revert back to taking startup instructions from /usr/lib/systemd/system/bindplane.service and the passwords in config.yaml would revert back to plaintext, which is not the desirable outcome.

It is therefore important to store the config.yaml in a safe place and without the plaintext secrets. The plaintext secrets should be stored securely in your secrets managers of choice.
Ensure the directory structure and the file content of the directories below, with the exception of bindplane_secrets.yml and ansible_vault.cred are checked into Github.

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

### Test bindplane-config-manager.sh script Manually

```bash
bindplane-config-manager.sh prepare
bindplane-config-manager.sh cleanup
```

---

## License

MIT License

## Author

**Olu Lawrence**  
Date: November 12, 2025

## Contributing
[Contributing Guidelines](https://github.com/Moyege8/plaintext-password-obfuscation/blob/main/contribution%20guidelines)


