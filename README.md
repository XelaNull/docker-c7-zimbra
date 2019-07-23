# Docker CentOS 7 Zimbra

This goal of this project is to make it simple and easy for anyone to create their own CentOS 7 based Zimbra server utilizing Docker container technology.

# Docker

## How to install Docker

CentOS: <https://docs.docker.com/install/linux/docker-ce/centos/> Ubuntu: <https://docs.docker.com/install/linux/docker-ce/ubuntu/>

## Downloading this repository with git

```
git clone https://github.com/XelaNull/docker-c7-zimbra
```

## Building the image

```
cd docker-c7-zimbra
docker build -t centos/zimbra:latest .
```

## Running the image

When you run the command below, it is going to run it within your shell so that you can easily see the output of the automated installation process. When you CTRL-C out of the image, it will stop the image, requiring you to restart it.

```
docker run -i --name=CENTOS-ZIMBRA \
  -p25:25/tcp -p80:80/tcp -p110:110/tcp -p143:143/tcp \
  -p443:443/tcp -p465:465/tcp -p587:587/tcp -p7071:7071/tcp \
  --hostname=YOUR.SERVER.FQDN.HERE -v /root/opt-zimbra:/opt/zimbra \
  centos/zimbra:latest
```

## Stopping or Starting the image

```
docker stop CENTOS-ZIMBRA
docker start CENTOS-ZIMBRA
```
