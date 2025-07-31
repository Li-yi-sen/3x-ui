#!/bin/bash

# 3X-UI 一键部署脚本
# 支持从GitHub releases文件一键下载和部署

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
plain='\033[0m'

echo -e "${blue}🚀 3X-UI 一键部署工具${plain}"
echo -e "${yellow}📦 支持releases压缩包下载和自动部署${plain}"
echo "======================================"

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}致命错误: ${plain} 请使用 root 权限运行此脚本\n" && exit 1

# 获取系统架构
get_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "arm32" ;;
        *) echo "amd64" ;;
    esac
}

# 检查系统要求
check_system() {
    echo -e "${purple}🔍 检查系统环境...${plain}"
    
    # 检查必要工具
    for tool in wget unzip tar; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${yellow}安装 $tool...${plain}"
            if command -v apt &> /dev/null; then
                apt update && apt install -y $tool
            elif command -v yum &> /dev/null; then
                yum install -y $tool
            elif command -v dnf &> /dev/null; then
                dnf install -y $tool
            fi
        fi
    done
    
    echo -e "${green}✅ 系统环境检查完成${plain}"
}

# 下载并解压项目
download_project() {
    echo -e "${purple}📥 下载项目文件...${plain}"
    
    # 设置下载URL - 使用用户的releases链接
    local zip_url="https://github.com/Li-yi-sen/3x-ui/releases/download/3x-ui/3x-ui2.1.zip"
    local install_script_url="https://github.com/Li-yi-sen/3x-ui/releases/download/3x-ui/default.sh"
    local temp_dir="/tmp/3x-ui-deploy"
    local project_dir="/opt/3x-ui"
    
    # 清理临时目录
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载zip文件
    echo -e "${yellow}正在下载项目包: $zip_url${plain}"
    if wget -O 3x-ui.zip "$zip_url"; then
        echo -e "${green}✅ 项目包下载成功${plain}"
    else
        echo -e "${red}❌ 项目包下载失败，请检查网络连接${plain}"
        exit 1
    fi
    
    # 下载安装脚本
    echo -e "${yellow}正在下载安装脚本: $install_script_url${plain}"
    if wget -O default.sh "$install_script_url"; then
        echo -e "${green}✅ 安装脚本下载成功${plain}"
        chmod +x default.sh
    else
        echo -e "${red}❌ 安装脚本下载失败，请检查网络连接${plain}"
        exit 1
    fi
    
    # 解压文件
    echo -e "${yellow}正在解压项目包...${plain}"
    if unzip -q 3x-ui.zip; then
        echo -e "${green}✅ 解压成功${plain}"
    else
        echo -e "${red}❌ 解压失败${plain}"
        exit 1
    fi
    
    # 移动到目标目录
    rm -rf "$project_dir"
    
    # 检查解压后的目录结构
    if [[ -d "3x-ui" ]]; then
        mv 3x-ui "$project_dir"
    elif [[ -d "3x-ui-main" ]]; then
        mv 3x-ui-main "$project_dir"
    else
        # 如果没有找到预期的目录，列出当前目录内容
        echo -e "${yellow}检查解压目录结构:${plain}"
        ls -la
        
        # 尝试移动第一个目录
        first_dir=$(ls -d */ 2>/dev/null | head -n1 | sed 's/\///')
        if [[ -n "$first_dir" ]]; then
            echo -e "${yellow}使用目录: $first_dir${plain}"
            mv "$first_dir" "$project_dir"
        else
            echo -e "${red}❌ 未找到项目目录${plain}"
            exit 1
        fi
    fi
    
    # 将安装脚本复制到项目目录
    cp default.sh "$project_dir/"
    cd "$project_dir"
    
    echo -e "${green}✅ 项目文件准备完成${plain}"
}

# 检查安装包
check_install_package() {
    echo -e "${purple}📦 检查安装包...${plain}"
    
    local arch=$(get_arch)
    local package_name="x-ui-linux-${arch}.tar.gz"
    
    if [[ ! -f "$package_name" ]]; then
        echo -e "${yellow}⚠️ 未找到安装包: $package_name${plain}"
        echo -e "${yellow}正在创建模拟安装包...${plain}"
        
        # 创建一个空的tar.gz文件作为占位符
        # 实际使用时，用户需要提供真实的安装包
        echo "请将真实的 $package_name 放置在此目录中" > package_readme.txt
        tar -czf "$package_name" package_readme.txt
        rm package_readme.txt
        
        echo -e "${red}⚠️ 注意: 这是一个占位符安装包${plain}"
        echo -e "${yellow}请从GitHub Releases页面下载真实的 $package_name${plain}"
        echo -e "${yellow}然后重新运行此脚本${plain}"
    else
        echo -e "${green}✅ 找到安装包: $package_name${plain}"
    fi
}

# 设置权限
set_permissions() {
    echo -e "${purple}🔧 设置文件权限...${plain}"
    
    # 设置脚本权限
    find . -name "*.sh" -exec chmod +x {} \;
    
    # 设置local-resources目录权限
    if [[ -d "local-resources" ]]; then
        find local-resources -name "*.sh" -exec chmod +x {} \;
    fi
    
    echo -e "${green}✅ 权限设置完成${plain}"
}

# 执行安装
run_installation() {
    echo -e "${purple}🚀 开始安装部署...${plain}"
    
    # 优先使用用户的default.sh脚本
    if [[ -f "default.sh" ]]; then
        echo -e "${yellow}使用default.sh安装脚本...${plain}"
        bash default.sh
    elif [[ -f "local-install-entry.sh" ]]; then
        echo -e "${yellow}使用主入口脚本安装...${plain}"
        bash local-install-entry.sh
    elif [[ -f "local-resources/scripts/local-install.sh" ]]; then
        echo -e "${yellow}使用本地安装脚本...${plain}"
        bash local-resources/scripts/local-install.sh
    else
        echo -e "${red}❌ 未找到安装脚本${plain}"
        echo -e "${yellow}可用的脚本文件:${plain}"
        find . -name "*.sh" -type f
        exit 1
    fi
}

# 显示部署结果
show_result() {
    echo ""
    echo -e "${green}🎉 一键部署完成！${plain}"
    echo "======================================"
    echo -e "${green}📍 主面板访问:${plain} http://您的服务器IP:2053"
    echo -e "${green}🛡️ 防火墙管理:${plain} http://您的服务器IP:5555"
    echo -e "${green}🎮 管理命令:${plain} x-ui"
    echo ""
    echo -e "${yellow}📚 详细文档:${plain}"
    echo -e "  - 完整说明: /opt/3x-ui/README-完整说明.md"
    echo -e "  - 部署说明: /opt/3x-ui/部署说明.md"
    echo -e "  - 版本更新: /opt/3x-ui/版本更新说明.md"
    echo ""
    echo -e "${green}默认登录信息:${plain}"
    echo -e "  用户名: admin"
    echo -e "  密码: admin"
    echo -e "${red}  ⚠️ 请立即修改默认密码！${plain}"
    echo "======================================"
}

# 主执行流程
main() {
    check_system
    download_project
    check_install_package
    set_permissions
    run_installation
    show_result
}

# 错误处理
trap 'echo -e "\n${red}❌ 部署过程中出现错误，正在清理...${plain}"; rm -rf /tmp/3x-ui-deploy; exit 1' ERR

# 开始执行
main "$@" 