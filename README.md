# Docker CentOS 7 Zimbra 8.8

This goal of this project is to make it simple and easy for anyone to create their own CentOS 7 Zimbra server utilizing Docker container technology. This Docker image contains both **Cron** and an **automated backup script**. **Zimbra requires Cron** for its many built-in automated scheduled tasks. Any Zimbra Docker image without Cron, is missing a critical ingredient for a fully functional Zimbra system. Zimbra Rocks! Build, Run, and Enjoy.

## Features

- Fix for Zimlet installation & GALSYNC account creation failure during Zimbra install
- Fix for zmconfigd stopping or not starting, through disabling of IPv6
- Auto-Restart of a single service if it is found stopped
- Auto-Restart of all services if more than one is found stopped
- Custom Automated Zimbra Backups
- Syslog-NG to facilitate standardizing log management
- Cron Scheduler, to facilitate the many built-in Zimbra Cron jobs
- Minimal Dockerfile image size (for CentOS 7): 519MB
- Excellent comments in short Dockerfile (roughly 60 lines)
- Successful build with only **four** settings in Dockerfile and **three** in the CLI 'docker run' command
- Heavily tested with hundreds of successful test validation builds
- Tested from both CentOS 7 and Ubuntu 19 Docker hosts

# Host Preparations

## Disable SELinux

It is strongly recommended to disable SELinux on your Docker host server. If you skip this step, be prepared to make SELinux modifications not covered by these instructions.

## Disable IPv6

Zimbra's zmconfigd does not play well with IPv6 in a Docker environment. If you aren't specifically using IPv6, you should consider disabling it on your Docker host.

## Uninstall any existing MTA

CentOS and Ubuntu both will have a mail daemon (postfix or sendmail) that is installed by default. You will need to remove this before you will be able to run your Zimbra Docker image.

```
yum -y remove postfix
apt-get remove postfix
```

## Docker Installation

**CentOS:** <https://docs.docker.com/install/linux/docker-ce/centos/>

**Ubuntu:** <https://docs.docker.com/install/linux/docker-ce/ubuntu/>

# Installation Process

## Downloading this repository with git

```
git clone https://github.com/XelaNull/docker-c7-zimbra
```

## Edit Dockerfile Variables

Your Zimbra Admin Password, timezone, and system memory should be set within the Dockerfile. Edit the Dockerfile and adjust the few variables at the top, then proceed on to building your image.

```
cd docker-c7-zimbra
vi Dockerfile
```

## Building the image

```
docker build -t docker-centos/zimbra:latest .
```

## Running the image

When you run the command below, it is going to run it within your shell so that you can easily see the output of the automated installation process. When the installation is complete, hit CTRL-C, which will stop the image. Afterwards, you'll want to start the image back up.

```
docker run -i --name=CENTOS-ZIMBRA \
  -p25:25/tcp -p80:80/tcp -p110:110/tcp -p143:143/tcp \
  -p443:443/tcp -p465:465/tcp -p587:587/tcp -p7071:7071/tcp \
  --sysctl net.ipv6.conf.all.disable_ipv6=1 \
  --hostname=YOUR.SERVER.FQDN.HERE \
  -v /root/opt-zimbra:/opt/zimbra \
  -v /root/zimbra-backups:/zimbra-backups \
  --restart=always docker-centos/zimbra:latest
```

- Make sure to change **YOUR.SERVER.FQDN.HERE**
- Also, examine the Docker host paths set for your Zimbra install (**/root/opt-zimbra**) and your Zimbra backups (**/root/zimbra-backups**). You'll probably want to set these to a different directory.

### Listing of TCP Ports Above

- 25 - SMTP
- 80 - HTTP (for Zimbra Webmail URL)
- 110 - POP3
- 143 - IMAP
- 443 - HTTPS (for Zimbra Webmail URL)
- 465 - IMAPS (Secure IMAP)
- 587 - SMTPS (Secure SMTP)
- 7071 - HTTPS (for Zimbra Admin URL)

## Stopping or Starting the image

Based on the **restart=always** CLI argument used with the 'docker run' command, if your Docker host is rebooted, as long as the Docker daemon starts on reboot this Zimbra docker image will also start up. If you need to stop or start the image, the two commands are below.

```
docker stop CENTOS-ZIMBRA
docker start CENTOS-ZIMBRA
```
