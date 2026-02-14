
- Prerequisites
- Part 1 - Prepare the ansible files and create the directory structure and encrypt the passwords.
- Part 2 Use Systemd LoadCredentialEncrypted to encrypt the password decryption key
- Part 3 - Deploy bindplane-config-manager.sh script that decrypts the passwords at Bindplane startup and creates the
    ○ Prologue
- Part 4 - Use Linux systemd startup process to run bindplane-config-manager_v2.sh
- If you change the passwords in config.yaml
- To change the vault password
- To update the the config.yaml with ldap
- To roll back Password obfuscation
- Miscellaneous
- Security Considerations
- Troubleshooting
- Check logs

Although this procedure was developed for Bindplane, it is applicable for all plaintext password obfuscations.

Password obfuscation version is a 3-part process, namely:

1. Prepare the ansible files and create the directory structure and encrypt the passwords.

2. Use Systemd LoadCredentialEncrypted to encrypt the password decryption key

3. Deploy bindplane-config-manager.sh script that creates Bindplane config.yaml file at startup.

4. Use Linux systemd startup process to run bindplane-config-manager.sh.

Prerequisites
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

Part 1 - Prepare the ansible files and create the directory structure and encrypt the passwords.

1. Create the directory structure as shown below:

```bash
cd /etc/bindplane
mkdir -p bindplane-config/templates
mkdir -p bindplane-config/vars

chmod -R 750 bindplane-config/templates
chmod -R 750 bindplane-config/vars
```

2. Create a jinja2 file from the config.yaml and store it in bindplane-config/templates

See example on Bindplane hosts stcxtqabpopcp51.x.tqa.ca, /etc/bindplane/bindplane-config/templates/bindplane-config.yml.j2
```bash
cd /etc/bindplane    # if you are not currently in /etc/bindplane directory

cp config.yaml bindplane-config/templates/bindplane-config.yml.j2
```

3. Using your favorite editor, replace the values you want to obfuscate with placeholder variables.

On the above-mentioned host, you can also run the grep command below to see the values that were obfuscated.
grep "{{" bindplane-config.yml.j2
  sessionSecret: "{{bindplane_session_secret}}"
    bindPassword: "{{bindPassword}}"
    password: "{{bindplane_postgres_password}}"

4. Verify the bindplane-config.yml.j2 is properly obfuscated by running the grep command again
```bash
grep "{{" bindplane-config.yml.j2
```

5. Using ansible-vault create the secrets files in /etc/bindplane/bindplane-config/vars
```bash
cd /etc/bindplane/bindplane-config/vars

ansible-vault create bindplane_secrets.yml
```

New Vault password:    #Enter a strong password of your choice. Store this password is a safe place. Cyberark for example.
Confirm New Vault password:

The file should look like this when done:
bindplane_admin_password: "replace this with the actual password"
bindplane_session_secret: "replace this with the actual value"
bindplane_postgres_password: "replace this with the actual password"

If you check the content of the bindplane_secrets.yml file, you will see that it is now encrypted and only you know the password for decrypting the secret file.
Run the command below to see:
```bash
more bindplane_secrets.yml
```

6. Create the ansible deploy file in /etc/bindplane/bindplane-config/deploy_bindplane.yml
See example #bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#
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

The content should look like this
[local]
localhost ansible_connection=local

localhost ansible_connection=local

bindplane-config directory structure should look like this:

/etc/bindplane
|—— bindplane-config
    |—— deploy_bindplane.yml
    |—— inventory.ini
    |—— templates
    |   └—— bindplane-config.yml.j2
    └—— vars
        └—— bindplane_secrets.yml

---------------------------------Part 1 is now omplete--------------------------

Part 2 Use Systemd LoadCredentialEncrypted to encrypt the password decryption key

1. From any directory of your choice create a file and enter into the file the vault key you created in Part 1, step 5 above. Let's call the file plaintext.txt.

2. Encrypt vault key using systemd-creds as shown below.
```bash
systemd-creds encrypt --name=ansible_vault_key plaintext.txt /etc/bindplane/bindplane-config/vaultkey/ansible_vault.cred
```

The above command will encrypt the vault key stored in plaintext.txt and store the encrypted vault key in /etc/bindplane/bindplane-config/vaultkey/ansible_vault.cred
3. Shred the plaintext.txt file and verify the file is no longer on the system.
```bash
shred -u plaintext.txt
```

---------------------------Part 2 is now complete-----------------------------------

Part 3 - Deploy bindplane-config-manager.sh script that decrypts the passwords at Bindplane startup and creates the config.yaml file.

1. Fetch the bash script bindplane-config-manager_v2.sh from Bindplane host stcxtqabpopcp51.x.tqa.can, /usr/local/bin directory and copy it to /usr/local/bin on the host on which you are password obfuscating

Make sure the permission looks as follows:
-rwxr-x---. 1 root root    3607 Feb 11 11:09 bindplane-config-manager_v2.sh

The workhorse script /usr/local/bin/bindplane-config-manager_v2.sh, when ran, requests the vault_key and uses the key to decrypt the encrypted passwords stored in bindplane_secrets.yml.
It generates the config.yaml using ansible-playbook deploy_bindplane.yml file which in turn uses bindplane-config.yml.j2 template
It cleans up all the temp files used in the process.

2. When you try to run the script manually as shown below, you would see that the script can only be ran by systemd service and not by a human
```bash
bindplane-config-manager_v2.sh prepare
```

[INFO] Preparing BindPlane configuration...
[ERROR] CREDENTIALS_DIRECTORY not available. Ensure the script is run via a systemd service with LoadCredentialEncrypted configured.

This is the expected error message.

**Prologue**

When you check the status of Bindplane by running the command
```bash
systemctl status bindplane
```

You see the following
○ bindplane.service - Bindplane is an observability pipeline that gives you the ability to collect, refine, and ship metrics, logs, and traces to any destination.
    Loaded: loaded (/usr/lib/systemd/system/bindplane.service; enabled; preset: disabled)
    Active: inactive (dead) since Tue 2025-11-11 14:09:39 EST; 10s ago
    Duration: 4d 2min 5.187s
      Docs: https://bindplane.com/docs/getting-started/quickstart-guide
    Process: 2736162 ExecStart=/usr/local/bin/bindplane serve --config /etc/bindplane/config.yaml (code=exited, status=0/SUCCESS)
  Main PID: 2736162 (code=exited, status=0/SUCCESS)
      CPU: 2h 1min 17.745s

Run the command below to see the content of the bindplane.service file.
```bash
more /usr/lib/systemd/system/bindplane.service
```

In Part 4, we are going to override bindplane service load path **/usr/lib/systemd/system/bindplane.service.**

-----once the script is in place and running correctly, part 3 is complete-----------------------

[INFO] Preparing BindPlane configuration...
[ERROR] CREDENTIALS_DIRECTORY not available. Ensure the script is run via a systemd service with LoadCredentialEncrypted configured.

This is the expected error message.

**Prologue**

When you check the status of Bindplane by running the command
```bash
systemctl status bindplane
```

You see the following
○ bindplane.service - Bindplane is an observability pipeline that gives you the ability to collect, refine, and ship metrics, logs, and traces to any destination.
    Loaded: loaded (/usr/lib/systemd/system/bindplane.service; enabled; preset: disabled)
    Active: inactive (dead) since Tue 2025-11-11 14:09:39 EST; 10s ago
    Duration: 4d 2min 5.187s
      Docs: https://bindplane.com/docs/getting-started/quickstart-guide
    Process: 2736162 ExecStart=/usr/local/bin/bindplane serve --config /etc/bindplane/config.yaml (code=exited, status=0/SUCCESS)
  Main PID: 2736162 (code=exited, status=0/SUCCESS)
      CPU: 2h 1min 17.745s

Run the command below to see the content of the bindplane.service file.
```bash
more /usr/lib/systemd/system/bindplane.service
```

In Part 4, we are going to override bindplane service load path **/usr/lib/systemd/system/bindplane.service.**

-----once the script is in place and running correctly, part 3 is complete-----------------------------

Part 4 - Use Linux systemd startup process to run bindplane-config-manager_v2.sh

1. Fetch the updated bindplane.service file which systemd will call at startup from stcxtqabpopcp51.x.tqa.can, /etc/systemd/system
and copy it to /etc/systemd/system on the Bindplane host on which you are password obfuscating.

The bindplane.service file looks like this.

Ensure the permission and ownership looks like this:

-rw-r----. 1 root    root    1479 Dec 16 10:16 bindplane.service

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

If you change the passwords in config.yaml

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

It is therefore important to store the config.yaml in a safe place.

## Miscellaneous

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

