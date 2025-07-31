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
    for tool in wget unzip tar systemctl; do
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

# 下载项目压缩包
download_project() {
    echo -e "${purple}📥 下载项目文件...${plain}"
    
    # 设置下载URL
    local zip_url="https://github.com/Li-yi-sen/3x-ui/releases/download/3x-ui/3x-ui2.1.zip"
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
    
    cd "$project_dir"
    echo -e "${green}✅ 项目文件准备完成${plain}"
}

# 下载二进制包
download_binary() {
    echo -e "${purple}📦 下载二进制安装包...${plain}"
    
    local arch=$(get_arch)
    local package_name="x-ui-linux-${arch}.tar.gz"
    local binary_url="https://github.com/Li-yi-sen/3x-ui/releases/download/3x-ui/${package_name}"
    
    echo -e "${yellow}正在下载二进制包: $binary_url${plain}"
    if wget -O "$package_name" "$binary_url"; then
        echo -e "${green}✅ 二进制包下载成功${plain}"
        
        # 解压二进制包
        echo -e "${yellow}正在解压二进制包...${plain}"
        if tar -xzf "$package_name"; then
            echo -e "${green}✅ 二进制包解压成功${plain}"
        else
            echo -e "${red}❌ 二进制包解压失败${plain}"
            exit 1
        fi
    else
        echo -e "${yellow}⚠️ 二进制包下载失败，将使用编译方式${plain}"
        return 1
    fi
}

# 编译安装
build_install() {
    echo -e "${purple}🔨 开始编译安装...${plain}"
    
    # 检查Go环境
    if ! command -v go &> /dev/null; then
        echo -e "${yellow}安装Go环境...${plain}"
        
        # 下载Go
        local go_version="1.21.5"
        local go_arch=$(get_arch)
        local go_url="https://golang.org/dl/go${go_version}.linux-${go_arch}.tar.gz"
        
        wget -O go.tar.gz "$go_url"
        tar -C /usr/local -xzf go.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        source /etc/profile
        
        # 设置Go环境变量
        export PATH=$PATH:/usr/local/go/bin
        export GOPROXY=https://goproxy.cn,direct
    fi
    
    # 编译项目
    echo -e "${yellow}正在编译项目...${plain}"
    if go build -o x-ui main.go; then
        echo -e "${green}✅ 编译成功${plain}"
    else
        echo -e "${red}❌ 编译失败${plain}"
        exit 1
    fi
}

# 安装服务
install_service() {
    echo -e "${purple}🔧 安装系统服务...${plain}"
    
    # 创建服务文件
    cat > /etc/systemd/system/x-ui.service << 'EOF'
[Unit]
Description=3x-ui Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/3x-ui
ExecStart=/opt/3x-ui/x-ui
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=x-ui

[Install]
WantedBy=multi-user.target
EOF

    # 创建防火墙服务文件
    cat > /etc/systemd/system/x-ui-firewall.service << 'EOF'
[Unit]
Description=3x-ui Firewall Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/3x-ui/web/firewall-server
ExecStart=/opt/3x-ui/web/firewall-server/firewall-server
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=x-ui-firewall

[Install]
WantedBy=multi-user.target
EOF

    # 设置权限
    chmod +x x-ui
    if [[ -f "web/firewall-server/firewall-server" ]]; then
        chmod +x web/firewall-server/firewall-server
    fi
    
    # 重载服务
    systemctl daemon-reload
    
    echo -e "${green}✅ 服务安装完成${plain}"
}

# 配置Nginx (80端口首页)
setup_nginx() {
    echo -e "${purple}🌐 配置Nginx服务...${plain}"
    
    # 安装Nginx
    if ! command -v nginx &> /dev/null; then
        if command -v apt &> /dev/null; then
            apt update && apt install -y nginx
        elif command -v yum &> /dev/null; then
            yum install -y nginx
        elif command -v dnf &> /dev/null; then
            dnf install -y nginx
        fi
    fi
    
    # 配置Nginx
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /opt/3x-ui/wwwroot;
    index index.html;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # 管理面板代理到2053端口
    location /admin {
        proxy_pass http://127.0.0.1:2053;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
    
    # 启动Nginx
    systemctl enable nginx
    systemctl restart nginx
    
    echo -e "${green}✅ Nginx配置完成${plain}"
}

# 启动服务
start_services() {
    echo -e "${purple}🚀 启动服务...${plain}"
    
    # 启动主服务
    systemctl enable x-ui
    systemctl start x-ui
    
    # 启动防火墙服务（5555端口）
    if [[ -f "web/firewall-server/firewall-server" ]]; then
        systemctl enable x-ui-firewall
        systemctl start x-ui-firewall
        echo -e "${green}✅ 防火墙服务已启动 (端口5555)${plain}"
    fi
    
    echo -e "${green}✅ 所有服务启动完成${plain}"
}

# 显示部署结果
show_result() {
    echo ""
    echo -e "${green}🎉 一键部署完成！${plain}"
    echo "======================================"
    echo -e "${green}📍 网站首页:${plain} http://您的服务器IP"
    echo -e "${green}📍 管理面板:${plain} http://您的服务器IP/admin 或 http://您的服务器IP:2053"
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
    echo ""
    echo -e "${yellow}服务状态检查:${plain}"
    echo -e "  主服务: $(systemctl is-active x-ui)"
    echo -e "  防火墙: $(systemctl is-active x-ui-firewall)"
    echo -e "  Nginx: $(systemctl is-active nginx)"
    echo "======================================"
}

# 主执行流程
main() {
    check_system
    download_project
    
    # 尝试下载二进制包，失败则编译
    if ! download_binary; then
        build_install
    fi
    
    install_service
    setup_nginx
    start_services
    show_result
}

# 错误处理
trap 'echo -e "\n${red}❌ 部署过程中出现错误，正在清理...${plain}"; rm -rf /tmp/3x-ui-deploy; exit 1' ERR

# 开始执行
main "$@" 
