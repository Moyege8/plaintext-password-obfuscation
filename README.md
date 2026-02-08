# plaintext-password-obfuscation
How to obfuscate plaintext passwords in config files
Genesis: The team I had just joined had been trying to onboard Bindplane for several years but were faced with the dilemma of how to hide the plaintext passwords in Bindplane config.yaml file.
I came up with the method described below.
Bindplane is a version of the open source OpenTelemetry.

The method described below, although implemented on Bindplane can be used for password obfuscation on any platform.
This the version of my password obfuscation solution, you will be prompted to provide the vault key everytime you run systemctl start bindplane.
Some clients may like this solution. However, the draw back of manually supplying the vault key Bindplane start up is, for automate Linux patch installations you will need to be present at odds hours (midnight) to provide the vault key.
In version 2 of this solution uses Systemd's LoadCredentialEncrypted to supply the vault key at start up.


**Part 1**
**Prequisites**
Create a backup copy of the config.yaml in a directory other than /etc/bindplane
e.g.
```bash
$ cp config.yaml config.yaml_`date "+%Y%m%d-%H%M%S"`
or preferrably on a very secure system or in github.
For added security place the passwords and secrets in config.yaml file with place holders, when backup the config and store the passwords and secrets in CyberArk or a password/secret manager of your choice.

Ensure ansible is installed

```bash
$ ansible --version
If ansible is not installed,
run
```bash
$ sudo dnf install ansible-core

Verify that jinja2 installed with ansible
```bash
$ ansible --version | grep -i jinja
-----------------------

Create the directory structure
```bash
$ cd /etc/bindplane
$ mkdir -p bindplane-config/templates
$ mkdir -p bindplane-config/vars
$ chmod -R 750 bindplane-config/templates
$ chmod -R 750 bindplane-config/vars

Create a jinja2 file from the config.yaml file and store it in bindplane-config/templates
A sample bindplane config.yaml file and jinja2 file are shown in ................

```bash
$ cd /etc/bindplane    # if you are no currently in the homedir
$ cp config.yaml bindplane-config/templates/bindplane-config.yml.j2

Replace the values you want to obfuscate with placeholder variables.

Use your favorite editor to edit the file.
Verify the bindplane-config.yml.j2 is properly obfuscated by run the grep command again

```bash
$ grep "{{" bindplane-config.yml.j2

Using ansible-vault create the secrets files in  /etc/bindplane/bindplane-config/vars
```bash
$ cd /etc/bindplane/bindplane-config/vars
$ ansible-vault create bindplane_secrets.yml
$ New Vault password: #Enter a strong password of your choice. Store this password is a safe place. Cyberark for example.
$ Confirm New Vault password:

The file should look like this when done:
bindplane_admin_password: "replace this with the actual password"
bindplane_session_secret: "replace this with the actual value"
bindplane_session_secret: "replace this with the actual value"
bindplane_postgres_password: "replace this with the actual password"

If you check the content of the file, you would see that is now encrypted and only you know the password for decrypting the secret file.
Run  the command below to see:
```bash
more bindplane_secrets.yml

Create the ansible deploy file in /etc/bindplane/bindplane-config/deploy_bindplane.yml
It should look like this
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

Create an ansible inventory file in /etc/bindplane/bindplane-config
vi inventory.ini
The content should look  like this
[local]
localhost ansible_connection=local
---- Part 1 is now complete--------------------------------------------------------------------------------------------------------------------------------------------------------------

**Part 2**
Copy the workhorse script /usr/local/bin/bindplane-config-manager.sh to /usr/local/bin on the host on which you are password obfuscating.
/usr/local/bin/bindplane-config-manager.sh, when ran, requests the vault key and uses the key to decrypt the encrypted passwords stored in bindplane_secrets.yml.
It generates the config.yaml using ansible-playbook deploy_bindplane.yml which in turn uses bindplane-config.yml.j2
It cleans up all temp files.

Test the script is running correctly by doing, from any directory:
```bash
$ bindplane-config-manager.sh prepare
The result should be:
[INFO] Preparing BindPlane configuration...
[INFO] Prompting for vault password...
🔒 Enter Ansible Vault password for BindPlane: ****************
[INFO] Decrypting passwords and generating config...
[INFO] Deploying config to /etc/bindplane/config.yaml
[INFO] Config deployed successfully

```bash
$ bindplane-config-manager.sh cleanup
[WARNING] Cleaning up config file...
[INFO] Config file securely removed

once the script is in place and running correctly, part 2 is complete
---------------Part 2---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

**Part 3**
**Prologue**
Part 3 involves using RHEL9's systemd startup process to run the bindplane-config-manager.sh script that you have setup above.
Prologue:
When you start bindplane by running the command
systemctl status bindplane
You see the following
o bindplane.service - Bindplane is an observability pipeline that gives you the ability to collect, refine, and ship metrics, logs, and traces to any destination.
    Loaded: loaded (**/usr/lib/systemd/system/bindplane.service**; enabled; preset: disabled)
    Active: inactive (dead) since Tue 2025-11-11 14:09:39 EST; 10s ago
  Duration: 4d 2min 5.187s
      Docs: https://bindplane.com/docs/getting-started/quickstart-guide
   Process: 2736162 ExecStart=/usr/local/bin/bindplane serve --config /etc/bindplane/config.yaml (code=exited, status=0/SUCCESS)
  Main PID: 2736162 (code=exited, status=0/SUCCESS)
       CPU: 2h 1min 17.745s

Observe that at Bindplane startup Systemd is loading /usr/lib/systemd/system/bindplane.service.
We are going to override it and make Systemd call our customized bindplane.service file that contains our bindplane-config-manager.sh script.
Run the command below to see the content of the file /usr/lib/systemd/system/bindplane.service.

```bash
more /usr/lib/systemd/system/bindplane.service

Copy our customized bindplane.service to /etc/systemd/system on the Bindplane host on which you are password obfuscating.
Check the content of the file to see how it is different from /usr/lib/systemd/system/bindplane.service.
When you run systemctl, it will now override /usr/lib/systemd/system/bindplane.service and take instructions from /etc/systemd/system/bindplane.service

To make systemctl now start using /etc/systemd/system/bindplane.service
do
```bash
systemctl daemon-reload
systemctl enable bindplane
systemctl start bindplane

do
```bash
systemctl status bindplane

● bindplane.service - BindPlane Server with Encrypted Configuration
    Loaded: loaded (/etc/systemd/system/bindplane.service; enabled; preset: disabled)
    Active: active (running) since Tue 2025-11-11 14:39:30 EST; 5s ago
      Docs: https://docs.bindplane.com
  Process: 3240468 ExecStartPre=/usr/local/bin/bindplane-config-manager.sh prepare (code=exited, status=0/SUCCESS)
  Process: 3240647 ExecStart=/usr/local/bin/bash -c sleep 15 && /usr/local/bin/bindplane-config-manager.sh cleanup & (code=exited, status=0/SUCCESS)
  Main PID: 3240646 (bindplane)

You can see that Systemd is now loading /etc/systemd/system/bindplane.service at startup.
You would also see that the bindplane's config.yaml is no longer visible in /etc/bindplane, creating an additional level of security.
--------------------------The bindplane password obfuscation process is now complete--------------------------------------------------

Checking the following into Github or a repository of your choice.
bindplane-config
├── deploy_bindplane.yml
├── inventory.ini
├── templates
│   └── bindplane-config.yml.j2

If you change the passwords in Bindplane config.yaml file, you will need to update bindplane_secrets.yml file, where the encrypted passwords are stored.
do
```bash
$ cd /etc/bindplane/bindplane-config/vars
$ ansible-vault edit bindplane_secrets.yml
You would be prompted for the vault password

To change the vault password do
```bash
$ cd /etc/bindplane/bindplane-config/vars
$ ansible-vault rekey bindplane_secrets.yml
You would be prompted for the current password and prompted to provide a new password

To update the the config.yaml with ldap
Update the /etc/bindplane/bindplane-config/templates/bindplane-config.yml.j2 file with ldap password placeholder
e.g. password: "{{bindplane_ldap_password}}"

Update the bindplane_secrets.yml file by using the edit command described earlier
ansible-vault edit bindplane_secrets.yml
-------

To role back Password obfuscation i.e. for some reason you want to revert back to having plaintext credentials in Bindplane config.yaml file.
1. Restore the most recent config.yaml, that you backed up during in the prerequisite section of this document, to /etc/bindplane
2. Remove the override in /etc/systemd/system/bindplane.service by renaming the file
```bash
$ cd /etc/systemd/system
$ mv bindplane.service bindplane.service_`date "+%Y%m%d-%H%M%S"`

3. Do
```bash
$ systemctl daemon-reload
$ systemctl enable bindplane
$ systemctl start bindplane

Bindplane will will revert to loading /usr/lib/systemd/system/bindplane.service at startup. And the config.yaml will be present in /etc/bindplane with plaintext credentials.
This is why it is important to store the config.yaml file backup in a secure manner.
------------------------The rollback is now complete---------------------------------

