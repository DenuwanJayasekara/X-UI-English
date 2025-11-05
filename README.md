# x-ui

Multi-protocol multi-user xray panel

# Features

- System status monitoring
- Support multi-user multi-protocol, web-based visual operations
- Supported protocols: vmess, vless, trojan, shadowsocks, dokodemo-door, socks, http
- Support configuring more transmission settings
- Traffic statistics, traffic limits, expiry time limits
- Customizable xray configuration template
- Support https access to panel (requires own domain + ssl certificate)
- Support one-click SSL certificate application and auto-renewal
- More advanced configuration options, see panel for details

# Installation & Update

```
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
```

## Manual Installation & Update

1. First download the latest archive from https://github.com/vaxilu/x-ui/releases, generally choose `amd64` architecture
2. Upload this archive to the server's `/root/` directory and log in to the server with `root` user

> If your server CPU architecture is not `amd64`, replace `amd64` in the command with other architectures

```
cd /root/
rm x-ui/ /usr/local/x-ui/ /usr/bin/x-ui -rf
tar zxvf x-ui-linux-amd64.tar.gz
chmod +x x-ui/x-ui x-ui/bin/xray-linux-* x-ui/x-ui.sh
cp x-ui/x-ui.sh /usr/bin/x-ui
cp -f x-ui/x-ui.service /etc/systemd/system/
mv x-ui/ /usr/local/
systemctl daemon-reload
systemctl enable x-ui
systemctl restart x-ui
```

## Install using Docker

> This docker tutorial and docker image are provided by [Chasing66](https://github.com/Chasing66)

1. Install docker

```shell
curl -fsSL https://get.docker.com | sh
```

2. Install x-ui

```shell
mkdir x-ui && cd x-ui
docker run -itd --network=host \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    --name x-ui --restart=unless-stopped \
    enwaiax/x-ui:latest
```

> Build your own image

```shell
docker build -t x-ui .
```

## SSL Certificate Application

> This feature and tutorial are provided by [FranzKafkaYu](https://github.com/FranzKafkaYu)

The script has built-in SSL certificate application functionality. To use this script to apply for certificates, you need to meet the following conditions:

- Know the Cloudflare registered email
- Know the Cloudflare Global API Key
- Domain has been resolved to the current server through Cloudflare

How to get Cloudflare Global API Key:
    ![](media/bda84fbc2ede834deaba1c173a932223.png)
    ![](media/d13ffd6a73f938d1037d0708e31433bf.png)

When using, just enter `domain`, `email`, `API KEY`. Schematic diagram is as follows:
        ![](media/2022-04-04_141259.png)

Notes:

- This script uses DNS API for certificate application
- Uses Let'sEncrypt as the CA by default
- Certificate installation directory is /root/cert directory
- Certificates applied by this script are all wildcard domain certificates

## Telegram Bot Usage (Under development, not available)

> This feature and tutorial are provided by [FranzKafkaYu](https://github.com/FranzKafkaYu)

X-UI supports daily traffic notifications, panel login reminders and other functions through Telegram bot. To use Telegram bot, you need to apply for it yourself
For specific application tutorial, please refer to [Blog link](https://coderfan.net/how-to-use-telegram-bot-to-alarm-you-when-someone-login-into-your-vps.html)
Usage instructions: Set bot-related parameters in the panel backend, specifically including

- Telegram bot Token
- Telegram bot ChatId
- Telegram bot periodic runtime, using crontab syntax  

Reference syntax:
- 30 * * * * * // Notify at 30 seconds of every minute
- @hourly      // Notify hourly
- @daily       // Notify daily (at midnight)
- @every 8h    // Notify every 8 hours  

Telegram notification content:
- Node traffic usage
- Panel login reminders
- Node expiry reminders
- Traffic warning reminders  

More features planned...
## Recommended Systems

- CentOS 7+
- Ubuntu 16+
- Debian 8+

# Frequently Asked Questions

## Migrate from v2-ui

First install the latest version of x-ui on the server where v2-ui is installed, then use the following command to migrate, which will migrate `all inbound account data` from v2-ui on this machine to x-ui. `Panel settings and username/password will not be migrated`

> After successful migration, please `close v2-ui` and `restart x-ui`, otherwise v2-ui's inbound will conflict with x-ui's inbound causing `port conflicts`

```
x-ui v2-ui
```

## Issue Closing

Various beginner questions are very frustrating

## Stargazers over time

[![Stargazers over time](https://starchart.cc/vaxilu/x-ui.svg)](https://starchart.cc/vaxilu/x-ui)
