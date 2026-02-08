# plaintext-password-obfuscation
How is to obfuscate plaintext passwords in config files
Genesis: The team I had just joined had been trying to onboard Bindplane for several years but were faced with the dilemma of how to hide the plaintext passwords in Bindplane config.yaml file.
I came up with the method described below.
Bindplane is version of the open source OpenTelemetry.

The method described below, although implemented on Bindplane can used for password obfuscation on any platform.

Here's the extracted text from the image:

**Part 1**
**Prequisites**
Create a backup copy of the config.yaml in a directory other than /etc/bindplane
e.g.
```bash
$ cp config.yaml config.yaml_`date "+%Y%m%d-%H%M%S"`
or preferrably in github

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
