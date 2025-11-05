#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Error: This script must be run as root!\n" && exit 1

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
    LOGE "System version not detected, please contact the script author!\n" && exit 1
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
        LOGE "Please use CentOS 7 or higher version!\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Please use Ubuntu 16 or higher version!\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Please use Debian 8 or higher version!\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Do you want to restart the panel? Restarting the panel will also restart xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/DenuwanJayasekara/X-UI-English/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force reinstall the latest version, data will not be lost, continue?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Cancelled"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/DenuwanJayasekara/X-UI-English/main/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "Update completed, panel has been automatically restarted "
        exit 0
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel? xray will also be uninstalled" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "Uninstall successful. If you want to delete this script, exit the script and run ${green}rm /usr/bin/x-ui -f${plain} to delete"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset the username and password to admin" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "Username and password have been reset to ${green}admin${plain}, please restart the panel now"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings? Account data will not be lost, username and password will not change" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "All panel settings have been reset to default values, please restart the panel now and use the default port ${green}54321${plain} to access the panel"
    confirm_restart
}

check_config() {
    # Try to get info using -show flag first
    info=$(/usr/local/x-ui/x-ui setting -show 2>&1)
    exit_code=$?
    
    if [[ $exit_code == 0 && -n "$info" && ! "$info" =~ "flag provided but not defined" ]]; then
        # Success with -show flag
        echo ""
        echo "$info"
        echo ""
        return 0
    fi
    
    # Fallback to reading from database
    LOGI "Reading panel settings from database..."
    echo ""
    
    panel_info=$(get_panel_info_from_db)
    if [[ $? != 0 ]]; then
        LOGE "Unable to retrieve panel settings. Please check if x-ui is properly installed and sqlite3 is available."
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    fi
    
    # Parse database info and display nicely
    port=$(echo "$panel_info" | grep "^port:" | cut -d: -f2)
    listen=$(echo "$panel_info" | grep "^listen:" | cut -d: -f2)
    username=$(echo "$panel_info" | grep "^username:" | cut -d: -f2)
    protocol=$(echo "$panel_info" | grep "^protocol:" | cut -d: -f2)
    base_path=$(echo "$panel_info" | grep "^base_path:" | cut -d: -f2)
    
    # Get server IP
    if [[ "$listen" == "0.0.0.0" ]] || [[ -z "$listen" ]]; then
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ -z "$server_ip" ]]; then
            server_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
        fi
        if [[ -z "$server_ip" ]]; then
            server_ip="localhost"
        fi
    else
        server_ip="$listen"
    fi
    
    echo "=========================================="
    echo "     Panel Service Status"
    echo "=========================================="
    echo "Panel Status:     Running"
    echo "Server IP:       $server_ip"
    echo "Panel Port:       $port"
    echo "Username:        $username"
    echo ""
    echo "Access Panel:"
    if [[ "$listen" == "0.0.0.0" ]] || [[ -z "$listen" ]]; then
        echo "  Local:   ${protocol}://localhost:${port}${base_path}"
        echo "  Network: ${protocol}://${server_ip}:${port}${base_path}"
    else
        echo "  ${protocol}://${server_ip}:${port}${base_path}"
    fi
    echo "=========================================="
    echo ""
    
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

set_port() {
    echo && echo -n -e "Enter port number [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Cancelled"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port}
        echo -e "Port setting completed, please restart the panel now and use the newly set port ${green}${port}${plain} to access the panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "Panel is already running, no need to start again. If you need to restart, please select restart"
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui started successfully"
        else
            LOGE "Panel startup failed, possibly because startup time exceeded 2 seconds, please check logs later"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "Panel is already stopped, no need to stop again"
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui and xray stopped successfully"
        else
            LOGE "Panel stop failed, possibly because stop time exceeded 2 seconds, please check logs later"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui and xray restarted successfully"
    else
        LOGE "Panel restart failed, possibly because startup time exceeded 2 seconds, please check logs later"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui auto-start on boot enabled successfully"
    else
        LOGE "x-ui auto-start on boot enable failed"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui auto-start on boot disabled successfully"
    else
        LOGE "x-ui auto-start on boot disable failed"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/DenuwanJayasekara/X-UI-English/raw/main/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "Failed to download script, please check if this machine can connect to Github"
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Script updated successfully, please run the script again" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "Panel is already installed, please do not install again"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Please install the panel first"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

get_panel_info_from_db() {
    local db_path="/etc/x-ui/x-ui.db"
    
    if [[ ! -f "$db_path" ]]; then
        return 1
    fi
    
    # Check if sqlite3 is available
    if ! command -v sqlite3 &> /dev/null; then
        return 1
    fi
    
    # Get port
    local port=$(sqlite3 "$db_path" "SELECT value FROM setting WHERE key='webPort';" 2>/dev/null)
    if [[ -z "$port" ]]; then
        port="54321"  # default
    fi
    
    # Get listen address
    local listen=$(sqlite3 "$db_path" "SELECT value FROM setting WHERE key='webListen';" 2>/dev/null)
    if [[ -z "$listen" ]]; then
        listen="0.0.0.0"
    fi
    
    # Get username
    local username=$(sqlite3 "$db_path" "SELECT username FROM user LIMIT 1;" 2>/dev/null)
    if [[ -z "$username" ]]; then
        username="admin"
    fi
    
    # Get cert files to determine protocol
    local cert_file=$(sqlite3 "$db_path" "SELECT value FROM setting WHERE key='webCertFile';" 2>/dev/null)
    local key_file=$(sqlite3 "$db_path" "SELECT value FROM setting WHERE key='webKeyFile';" 2>/dev/null)
    local protocol="http"
    if [[ -n "$cert_file" && -n "$key_file" ]]; then
        protocol="https"
    fi
    
    # Get base path
    local base_path=$(sqlite3 "$db_path" "SELECT value FROM setting WHERE key='webBasePath';" 2>/dev/null)
    if [[ -z "$base_path" ]]; then
        base_path="/"
    fi
    
    echo "port:$port"
    echo "listen:$listen"
    echo "username:$username"
    echo "protocol:$protocol"
    echo "base_path:$base_path"
    return 0
}

get_panel_info() {
    if [[ ! -f /usr/local/x-ui/x-ui ]]; then
        return 1
    fi
    
    # Try -show flag first (for newer versions)
    info=$(/usr/local/x-ui/x-ui setting -show 2>/dev/null)
    if [[ $? == 0 && -n "$info" ]]; then
        echo "$info"
        return 0
    fi
    
    # Fallback to database reading
    get_panel_info_from_db
    return $?
}

show_web_ui_url() {
    check_status
    if [[ $? != 0 ]]; then
        return
    fi
    
    panel_info=$(get_panel_info)
    if [[ $? != 0 ]]; then
        return
    fi
    
    # Check if output is from database (key:value format) or from -show flag (formatted text)
    if echo "$panel_info" | grep -q "port:"; then
        # Database format
        port=$(echo "$panel_info" | grep "^port:" | cut -d: -f2)
        listen=$(echo "$panel_info" | grep "^listen:" | cut -d: -f2)
        protocol=$(echo "$panel_info" | grep "^protocol:" | cut -d: -f2)
        base_path=$(echo "$panel_info" | grep "^base_path:" | cut -d: -f2)
    else
        # -show flag format
        port=$(echo "$panel_info" | grep -i "Panel Port:" | awk '{print $3}')
        listen=$(echo "$panel_info" | grep -i "Server IP:" | awk '{print $3}')
        protocol=$(echo "$panel_info" | grep -i "Access Panel:" | grep -o "http[s]*" | head -1)
        base_path=$(echo "$panel_info" | grep -i "Access Panel:" | grep -oP '://[^:]+:\d+\K.*' | head -1)
    fi
    
    if [[ -n "$port" && "$port" != "0" ]]; then
        if [[ "$listen" == "0.0.0.0" ]] || [[ -z "$listen" ]] || [[ "$listen" == "Unknown" ]]; then
            # Get server IP
            server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
            if [[ -z "$server_ip" ]]; then
                server_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
            fi
            if [[ -z "$server_ip" ]]; then
                server_ip=$(hostname -i 2>/dev/null | awk '{print $1}')
            fi
            if [[ -z "$server_ip" ]]; then
                server_ip="localhost"
            fi
        else
            server_ip="$listen"
        fi
        
        if [[ -z "$protocol" ]]; then
            protocol="http"
        fi
        
        if [[ -z "$base_path" ]]; then
            base_path="/"
        fi
        
        echo -e "Web UI URL:       ${green}${protocol}://${server_ip}:${port}${base_path}${plain}"
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Panel status: ${green}Running${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Panel status: ${yellow}Not Running${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Panel status: ${red}Not Installed${plain}"
        ;;
    esac
    show_xray_status
    show_web_ui_url
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Auto-start on boot: ${green}Yes${plain}"
    else
        echo -e "Auto-start on boot: ${red}No${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "xray status: ${green}Running${plain}"
    else
        echo -e "xray status: ${red}Not Running${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
    LOGD "******Usage Instructions******"
    LOGI "This script will use Acme script to apply for certificates, please ensure:"
    LOGI "1. You know the Cloudflare registered email"
    LOGI "2. You know the Cloudflare Global API Key"
    LOGI "3. Domain has been resolved to the current server through Cloudflare"
    LOGI "4. The default installation path for certificates applied by this script is /root/cert directory"
    confirm "I have confirmed the above content [y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "Installing Acme script"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "Failed to install acme script"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        LOGD "Please set domain name:"
        read -p "Input your domain here:" CF_Domain
        LOGD "Your domain is set to: ${CF_Domain}"
        LOGD "Please set API key:"
        read -p "Input your key here:" CF_GlobalKey
        LOGD "Your API key is: ${CF_GlobalKey}"
        LOGD "Please set registered email:"
        read -p "Input your email here:" CF_AccountEmail
        LOGD "Your registered email is: ${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "Failed to change default CA to Let's Encrypt, script exited"
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "Certificate issuance failed, script exited"
            exit 1
        else
            LOGI "Certificate issued successfully, installing..."
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
        --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
        --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "Certificate installation failed, script exited"
            exit 1
        else
            LOGI "Certificate installed successfully, enabling auto-update..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "Auto-update setup failed, script exited"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "Certificate has been installed and auto-update has been enabled, details are as follows"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
    echo "x-ui management script usage: "
    echo "------------------------------------------"
    echo "x-ui              - Show management menu (more features)"
    echo "x-ui start        - Start x-ui panel"
    echo "x-ui stop         - Stop x-ui panel"
    echo "x-ui restart      - Restart x-ui panel"
    echo "x-ui status       - Check x-ui status"
    echo "x-ui enable       - Enable x-ui auto-start on boot"
    echo "x-ui disable      - Disable x-ui auto-start on boot"
    echo "x-ui log          - View x-ui logs"
    echo "x-ui v2-ui        - Migrate v2-ui account data from this machine to x-ui"
    echo "x-ui update       - Update x-ui panel"
    echo "x-ui install      - Install x-ui panel"
    echo "x-ui uninstall    - Uninstall x-ui panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}x-ui Panel Management Script${plain}
  ${green}0.${plain} Exit script
————————————————
  ${green}1.${plain} Install x-ui
  ${green}2.${plain} Update x-ui
  ${green}3.${plain} Uninstall x-ui
————————————————
  ${green}4.${plain} Reset username and password
  ${green}5.${plain} Reset panel settings
  ${green}6.${plain} Set panel port
  ${green}7.${plain} View current panel settings
————————————————
  ${green}8.${plain} Start x-ui
  ${green}9.${plain} Stop x-ui
  ${green}10.${plain} Restart x-ui
  ${green}11.${plain} View x-ui status
  ${green}12.${plain} View x-ui logs
————————————————
  ${green}13.${plain} Enable x-ui auto-start on boot
  ${green}14.${plain} Disable x-ui auto-start on boot
————————————————
  ${green}15.${plain} One-click install BBR (latest kernel)
  ${green}16.${plain} One-click apply SSL certificate (via acme)
 "
    show_status
    echo && read -p "Please enter your choice [0-16]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && check_config
        ;;
    8)
        check_install && start
        ;;
    9)
        check_install && stop
        ;;
    10)
        check_install && restart
        ;;
    11)
        check_install && status
        ;;
    12)
        check_install && show_log
        ;;
    13)
        check_install && enable
        ;;
    14)
        check_install && disable
        ;;
    15)
        install_bbr
        ;;
    16)
        ssl_cert_issue
        ;;
    *)
        LOGE "Please enter a valid number [0-16]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
