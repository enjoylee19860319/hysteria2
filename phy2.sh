#!/usr/bin/env bash
# ==============================================================================
# Hysteria2 极简依赖安装脚本 (phy2.sh)
# 适配系统: Linux (Debian / Ubuntu / CentOS / Rocky / AlmaLinux / Fedora / Alpine / Arch 等)
# 设计原则: 零破坏性系统环境、最小必要依赖、确保 hysteria2.py 运行无虞
# ==============================================================================

set -euo pipefail

# 终端输出配色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${PLAIN} $1"; }
log_succ() { echo -e "${GREEN}[OK]${PLAIN} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${PLAIN} $1"; }
log_err()  { echo -e "${RED}[ERROR]${PLAIN} $1"; }

# 1. 检查 Root 权限
check_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_err "请使用 root 权限运行此脚本 (例如: sudo bash $0)"
        exit 1
    fi
}

# 2. 识别操作系统与包管理器类型
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_err "未找到 /etc/os-release 文件，无法识别当前系统！"
        exit 1
    fi

    . /etc/os-release
    local os_id="${ID:-}"
    local os_like="${ID_LIKE:-}"

    if [[ "$os_id" =~ ^(ubuntu|debian|kali|linuxmint|pop|raspbian|armbian)$ ]] || [[ "$os_like" =~ (debian|ubuntu) ]]; then
        PKG_MANAGER="apt"
    elif [[ "$os_id" =~ ^(centos|rhel|rocky|almalinux|fedora|ol|amzn)$ ]] || [[ "$os_like" =~ (rhel|centos|fedora) ]]; then
        PKG_MANAGER="dnf_or_yum"
        OS_ID="$os_id"
    elif [[ "$os_id" =~ ^(arch|manjaro|endeavouros)$ ]] || [[ "$os_like" =~ arch ]]; then
        PKG_MANAGER="pacman"
    elif [[ "$os_id" == "alpine" ]]; then
        PKG_MANAGER="apk"
    else
        log_err "暂不支持的 Linux 发行版: ${os_id} (${os_like})"
        exit 1
    fi
    log_info "检测到操作系统: ${PRETTY_NAME:-$os_id} (包管理器: ${PKG_MANAGER})"
}

# 3. 极简安装必要依赖
install_dependencies() {
    log_info "正在安装 Hysteria2 运行必需的最小依赖集..."

    case "$PKG_MANAGER" in
        apt)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -y -q
            apt-get install -y -q --no-install-recommends \
                curl \
                ca-certificates \
                openssl \
                qrencode \
                iptables \
                iproute2 \
                nano \
                python3 \
                python3-requests
            ;;

        dnf_or_yum)
            local cmd="yum"
            if command -v dnf &>/dev/null; then
                cmd="dnf"
            fi

            # 非 Fedora 的 RHEL 衍生版启用 EPEL 源以支持 qrencode
            if [[ "${OS_ID:-}" != "fedora" ]]; then
                $cmd install -y epel-release || true
            fi

            $cmd install -y \
                curl \
                ca-certificates \
                openssl \
                qrencode \
                iptables \
                iproute \
                nano \
                python3 \
                python3-requests || {
                    # 备用方案：极简镜像若仓库无 python3-requests 则安装 pip 并补充 requests
                    log_warn "未在官方源找到 python3-requests，尝试使用 pip 补齐..."
                    $cmd install -y python3-pip
                    python3 -m pip install -q requests
                }
            ;;

        pacman)
            pacman -Sy --noconfirm --needed \
                curl \
                ca-certificates \
                openssl \
                qrencode \
                iptables \
                iproute2 \
                nano \
                python \
                python-requests
            ;;

        apk)
            apk update
            apk add --no-cache \
                bash \
                curl \
                ca-certificates \
                openssl \
                qrencode \
                iptables \
                ip6tables \
                iproute2 \
                nano \
                python3 \
                py3-requests
            ;;
    esac

    log_succ "基础依赖安装完毕！"
}

# 4. 验证 Python 与核心模块
verify_environment() {
    log_info "验证 Python 及必要模块环境..."
    if command -v python3 &>/dev/null && python3 -c "import requests, ipaddress, urllib, hashlib, pathlib, shlex" &>/dev/null; then
        log_succ "环境验证通过：Python3 与全部核心模块均正常可用。"
    else
        log_err "Python 环境验证失败，请检查网络或系统包管理器配置！"
        exit 1
    fi
}

main() {
    check_root
    detect_os
    install_dependencies
    verify_environment
    echo -e "\n${GREEN}====================================================${PLAIN}"
    echo -e "${GREEN}  Hysteria2 依赖环境初始化完成！${PLAIN}"
    echo -e "  接下来您可以直接运行:"
    echo -e "  ${YELLOW}python3 hysteria2.py${PLAIN}"
    echo -e "${GREEN}====================================================${PLAIN}\n"
}

main "$@"
