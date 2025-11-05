#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}Architecture detection failed, using default architecture: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit systems (x86), please use 64-bit systems (x86_64). If the detection is incorrect, please contact the author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher version!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher version!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher version!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar sqlite git unzip -y
    else
        apt install wget curl tar sqlite3 git unzip -y
    fi
}

install_golang() {
    if command -v go &> /dev/null; then
        echo -e "${green}Go is already installed${plain}"
        return 0
    fi
    
    echo -e "${yellow}Installing Go...${plain}"
    if [[ x"${release}" == x"centos" ]]; then
        yum install golang -y
    else
        apt install golang-go -y
    fi
    
    if ! command -v go &> /dev/null; then
        echo -e "${red}Failed to install Go. Building from source requires Go 1.16 or higher.${plain}"
        return 1
    fi
    return 0
}

build_from_source() {
    local build_dir="/tmp/x-ui-build"
    local repo_url="https://github.com/DenuwanJayasekara/X-UI-English.git"
    
    echo -e "${yellow}Building x-ui from source...${plain}"
    
    # Install Go if needed
    install_golang
    if [[ $? != 0 ]]; then
        return 1
    fi
    
    # Clean build directory
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Clone repository
    git clone "$repo_url" . || {
        echo -e "${red}Failed to clone repository${plain}"
        return 1
    }
    
    # Build
    echo -e "${yellow}Compiling x-ui...${plain}"
    CGO_ENABLED=1 go build -o x-ui main.go
    if [[ $? != 0 ]]; then
        echo -e "${red}Build failed${plain}"
        return 1
    fi
    
    # Create directory structure
    mkdir -p x-ui-package/bin
    cp x-ui x-ui-package/x-ui
    cp x-ui.service x-ui-package/x-ui.service
    cp x-ui.sh x-ui-package/x-ui.sh
    
    # Download xray binary
    cd x-ui-package/bin
    if [[ "$arch" == "amd64" ]]; then
        wget -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
        unzip -q xray.zip
        rm xray.zip geoip.dat geosite.dat
        mv xray xray-linux-amd64
    elif [[ "$arch" == "arm64" ]]; then
        wget -O xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-arm64-v8a.zip
        unzip -q xray.zip
        rm xray.zip geoip.dat geosite.dat
        mv xray xray-linux-arm64
    fi
    
    # Download geo files
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    
    cd "$build_dir"
    mv x-ui-package x-ui
    cd /usr/local
    
    # Replace old installation
    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi
    
    mv "$build_dir/x-ui" /usr/local/
    rm -rf "$build_dir"
    
    chmod +x /usr/local/x-ui/x-ui /usr/local/x-ui/bin/xray-linux-${arch}
    echo -e "${green}Build from source completed successfully${plain}"
    return 0
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security reasons, after installation/update, you must change the port and account password${plain}"
    read -p "Confirm to continue?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow}Your account password will be set to:${config_password}${plain}"
        read -p "Please set panel access port:" config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}Confirming settings, applying...${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}Account password setting completed${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Panel port setting completed${plain}"
    else
        echo -e "${red}Cancelled, all settings are default, please modify them in time${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    # Check if user wants to build from source
    if [[ "$1" == "build" ]] || [[ "$BUILD_FROM_SOURCE" == "true" ]]; then
        if build_from_source; then
            last_version="source"
        else
            echo -e "${red}Build from source failed, falling back to pre-built binary${plain}"
            # Fall through to download method
        fi
    fi
    
    # If not building from source or build failed, download pre-built
    if [[ "$last_version" != "source" ]]; then
        if [ $# == 0 ] || [[ "$1" != "build" ]]; then
            last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            if [[ ! -n "$last_version" ]]; then
                echo -e "${red}Failed to detect x-ui version, possibly exceeded Github API limit, please try again later, or manually specify x-ui version to install${plain}"
                exit 1
            fi
            echo -e "Detected x-ui latest version: ${last_version}, starting installation"
            wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
            if [[ $? -ne 0 ]]; then
                echo -e "${red}Failed to download x-ui, please ensure your server can download files from Github${plain}"
                exit 1
            fi
        else
            last_version=$1
            url="https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
            echo -e "Starting installation of x-ui v$1"
            wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
            if [[ $? -ne 0 ]]; then
                echo -e "${red}Failed to download x-ui v$1, please ensure this version exists${plain}"
                exit 1
            fi
        fi

        if [[ -e /usr/local/x-ui/ ]]; then
            rm /usr/local/x-ui/ -rf
        fi

        tar zxvf x-ui-linux-${arch}.tar.gz
        rm x-ui-linux-${arch}.tar.gz -f
        cd x-ui
        chmod +x x-ui bin/xray-linux-${arch}
    fi
    
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/DenuwanJayasekara/X-UI-English/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    if [[ "$last_version" == "source" ]]; then
        echo -e "${green}x-ui (built from source)${plain} installation completed, panel has been started,"
    else
        echo -e "${green}x-ui v${last_version}${plain} installation completed, panel has been started,"
    fi
    echo -e ""
    echo -e "x-ui management script usage: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Show management menu (more features)"
    echo -e "x-ui start        - Start x-ui panel"
    echo -e "x-ui stop         - Stop x-ui panel"
    echo -e "x-ui restart      - Restart x-ui panel"
    echo -e "x-ui status       - Check x-ui status"
    echo -e "x-ui enable       - Enable x-ui auto-start on boot"
    echo -e "x-ui disable      - Disable x-ui auto-start on boot"
    echo -e "x-ui log          - View x-ui logs"
    echo -e "x-ui v2-ui        - Migrate v2-ui account data from this machine to x-ui"
    echo -e "x-ui update       - Update x-ui panel"
    echo -e "x-ui install      - Install x-ui panel"
    echo -e "x-ui uninstall    - Uninstall x-ui panel"
    echo -e "----------------------------------------------"
}

echo -e "${green}Starting installation${plain}"
install_base
install_x-ui $1
