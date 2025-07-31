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
echo -e "${yellow}📦 直接从源码编译部署，简单高效${plain}"
echo -e "${green}🎯 功能: 下载源码 → 安装环境 → 编译安装 → 配置服务 → 启动运行${plain}"
echo -e "${purple}🔧 自动安装: Go编译环境、Git工具、Nginx服务器${plain}"
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
    for tool in wget unzip tar systemctl git; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${yellow}安装 $tool...${plain}"
            if command -v apt &> /dev/null; then
                apt update && apt install -y $tool
            elif command -v yum &> /dev/null; then
                yum install -y $tool
            elif command -v dnf &> /dev/null; then
                dnf install -y $tool
            else
                echo -e "${red}❌ 无法安装 $tool，请手动安装${plain}"
                exit 1
            fi
        fi
    done
    
    echo -e "${green}✅ 系统环境检查完成${plain}"
}

# 下载项目压缩包
download_project() {
    echo -e "${purple}📥 下载项目文件...${plain}"
    
    # 设置下载URL - 使用raw链接从仓库根目录下载
    local zip_url="https://github.com/Li-yi-sen/3x-ui/raw/main/3x-ui2.1.zip"
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
    
    # 验证项目结构
    if [[ -f "main.go" ]]; then
        echo -e "${green}✅ 项目文件准备完成，找到main.go${plain}"
    else
        echo -e "${yellow}⚠️ 未找到main.go，检查项目结构...${plain}"
        ls -la
    fi
}

# 清理临时文件
cleanup_temp_files() {
    echo -e "${yellow}🧹 清理临时文件...${plain}"
    
    # 只在/opt/3x-ui目录中清理
    if [[ "$(pwd)" == "/opt/3x-ui" ]]; then
        rm -f go.tar.gz *.tar.gz 2>/dev/null || true
        echo -e "${green}✅ 临时文件清理完成${plain}"
    fi
    
    # 清理/tmp目录
    rm -rf /tmp/3x-ui-deploy 2>/dev/null || true
}

# 编译安装
build_install() {
    echo -e "${purple}🔨 开始编译安装...${plain}"
    
    # 确保在项目目录中
    if [[ ! -f "main.go" ]]; then
        echo -e "${red}❌ 未找到main.go文件，请确保在项目根目录${plain}"
        return 1
    fi
    
    # 检查Go环境
    if ! command -v go &> /dev/null || [[ $(go version | grep -o 'go[0-9]\+\.[0-9]\+' | head -1) < "go1.20" ]]; then
        echo -e "${yellow}安装Go环境...${plain}"
        
        # 移除旧版本Go
        rm -rf /usr/local/go
        
        # 下载最新稳定版Go
        local go_version="1.23.4"
        local go_arch=$(get_arch)
        local go_url="https://go.dev/dl/go${go_version}.linux-${go_arch}.tar.gz"
        
        echo -e "${yellow}下载Go ${go_version}...${plain}"
        if wget -O go.tar.gz "$go_url"; then
            tar -C /usr/local -xzf go.tar.gz
            rm -f go.tar.gz
            
                         # 设置Go环境变量
             export PATH=/usr/local/go/bin:$PATH
             export GOPROXY=https://goproxy.cn,https://proxy.golang.org,direct
             export GOSUMDB=sum.golang.org
             export GOTOOLCHAIN=local
             export GO111MODULE=on
            
                         # 永久设置环境变量
             echo 'export PATH=/usr/local/go/bin:$PATH' > /etc/profile.d/go.sh
             echo 'export GOPROXY=https://goproxy.cn,https://proxy.golang.org,direct' >> /etc/profile.d/go.sh
             echo 'export GOSUMDB=sum.golang.org' >> /etc/profile.d/go.sh
             echo 'export GOTOOLCHAIN=local' >> /etc/profile.d/go.sh
             echo 'export GO111MODULE=on' >> /etc/profile.d/go.sh
            
            echo -e "${green}✅ Go环境安装成功${plain}"
        else
            echo -e "${red}❌ Go下载失败${plain}"
            return 1
        fi
         else
         echo -e "${green}✅ Go环境已存在${plain}"
         export PATH=/usr/local/go/bin:$PATH
         export GOPROXY=https://goproxy.cn,https://proxy.golang.org,direct
         export GOSUMDB=sum.golang.org
         export GOTOOLCHAIN=local
         export GO111MODULE=on
     fi
    
    # 验证Go版本
    echo -e "${yellow}Go版本: $(go version)${plain}"
    
    # 验证Git工具
    if ! command -v git &> /dev/null; then
        echo -e "${red}❌ Git工具未安装，正在安装...${plain}"
        if command -v apt &> /dev/null; then
            apt update && apt install -y git
        elif command -v yum &> /dev/null; then
            yum install -y git
        elif command -v dnf &> /dev/null; then
            dnf install -y git
        fi
        
        # 再次验证
        if ! command -v git &> /dev/null; then
            echo -e "${red}❌ Git安装失败，编译无法继续${plain}"
            return 1
        fi
    fi
    
    echo -e "${green}✅ Git工具可用：$(git --version)${plain}"
    
    # 清理模块缓存
    go clean -modcache 2>/dev/null || true
    
    # 编译项目
    echo -e "${yellow}正在编译项目...${plain}"
    echo -e "${purple}📡 正在下载Go依赖包，请稍等...${plain}"
    
    # 设置编译选项
    export CGO_ENABLED=0
    export GOOS=linux
    export GOARCH=$(get_arch)
    
    # 尝试编译，支持重试
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if [[ $retry_count -gt 0 ]]; then
            echo -e "${yellow}🔄 第 $((retry_count + 1)) 次编译尝试...${plain}"
            # 清理模块缓存重试
            go clean -modcache 2>/dev/null || true
        fi
        
        if go mod tidy && go build -ldflags="-s -w" -o x-ui main.go; then
            echo -e "${green}✅ 编译成功${plain}"
            
            # 创建防火墙服务器二进制
            if [[ -d "web/firewall-server" ]]; then
                echo -e "${yellow}编译防火墙服务器...${plain}"
                cd web/firewall-server
                if go build -ldflags="-s -w" -o firewall-server main.go; then
                    echo -e "${green}✅ 防火墙服务器编译成功${plain}"
                else
                    echo -e "${yellow}⚠️ 防火墙服务器编译失败，将跳过${plain}"
                fi
                cd ../..
            fi
            
            return 0
        else
            ((retry_count++))
            if [[ $retry_count -lt $max_retries ]]; then
                echo -e "${yellow}⚠️ 编译失败，30秒后重试 ($retry_count/$max_retries)...${plain}"
                sleep 30
            fi
        fi
    done
    
    echo -e "${red}❌ 编译失败，已尝试 $max_retries 次${plain}"
    echo -e "${yellow}💡 可能的原因：${plain}"
    echo -e "  - 网络连接问题，无法下载Go依赖包"
    echo -e "  - 磁盘空间不足"
    echo -e "  - 内存不足"
    echo -e "  - Go模块代理服务器问题"
    return 1
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
    
    # 服务状态检查API
    location /api/status {
        add_header Content-Type application/json;
        return 200 '{"status":"online","services":{"main":"active","firewall":"active","nginx":"active"}}';
    }
}
EOF
    
    # 更新首页文件，添加实时服务状态
    cat > /opt/3x-ui/wwwroot/status.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>服务状态 - 3X-UI</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .status-card { margin: 10px 0; padding: 15px; border-radius: 5px; border-left: 4px solid #ddd; }
        .status-online { border-left-color: #4CAF50; background: #f1f8e9; }
        .status-offline { border-left-color: #f44336; background: #ffebee; }
        .btn { display: inline-block; padding: 10px 20px; margin: 5px; text-decoration: none; border-radius: 4px; color: white; }
        .btn-primary { background: #2196F3; }
        .btn-success { background: #4CAF50; }
        .btn-warning { background: #FF9800; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ 3X-UI 服务状态</h1>
        
        <div class="status-card status-online">
            <h3>✅ 主服务 (端口 2053)</h3>
            <p>3X-UI 管理面板服务正在运行</p>
            <a href="/admin" class="btn btn-primary">访问管理面板</a>
        </div>
        
        <div class="status-card status-online">
            <h3>🛡️ 防火墙服务 (端口 5555)</h3>
            <p>防火墙管理服务正在运行</p>
            <a href="http://localhost:5555" class="btn btn-warning">访问防火墙管理</a>
        </div>
        
        <div class="status-card status-online">
            <h3>🌐 Web服务 (端口 80)</h3>
            <p>Nginx Web服务器正在运行</p>
            <a href="/" class="btn btn-success">返回首页</a>
        </div>
        
        <h2>📊 快速链接</h2>
        <p>
            <a href="/" class="btn btn-primary">首页</a>
            <a href="/admin" class="btn btn-success">管理面板</a>
            <a href="http://localhost:5555" class="btn btn-warning">防火墙管理</a>
        </p>
        
        <h2>📝 默认登录信息</h2>
        <p><strong>用户名:</strong> admin</p>
        <p><strong>密码:</strong> admin</p>
        <p style="color: red;"><strong>⚠️ 请立即修改默认密码！</strong></p>
    </div>
</body>
</html>
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
    echo -e "${blue}✨ 优化流程：源码编译，无冗余下载${plain}"
    echo "======================================"
    echo -e "${green}📍 网站首页:${plain} http://您的服务器IP"
    echo -e "${green}📊 服务状态:${plain} http://您的服务器IP/status.html"
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
    
    # 直接编译安装，不下载额外的二进制包
    echo -e "${yellow}🔨 开始编译安装源码包...${plain}"
    if ! build_install; then
        echo -e "${red}❌ 编译安装失败${plain}"
        echo -e "${yellow}💡 建议解决方案:${plain}"
        echo -e "  1. 检查网络连接是否正常"
        echo -e "  2. 确保有足够的磁盘空间和内存"
        echo -e "  3. 检查Go环境是否正常安装"
        echo -e "  4. 联系技术支持获取帮助"
        exit 1
    fi
    
    # 验证关键文件是否存在
    if [[ ! -f "x-ui" ]]; then
        echo -e "${red}❌ 主程序文件不存在${plain}"
        exit 1
    fi
    
    install_service
    setup_nginx
    start_services
    cleanup_temp_files
    show_result
}

# 清理函数（在脚本开始时定义）
cleanup_on_error() {
    echo -e "\n${red}❌ 部署过程中出现错误，正在清理...${plain}"
    rm -rf /tmp/3x-ui-deploy 2>/dev/null || true
    if [[ "$(pwd)" == "/opt/3x-ui" ]]; then
        rm -f go.tar.gz *.tar.gz 2>/dev/null || true
    fi
}

# 错误处理
trap 'cleanup_on_error; exit 1' ERR

# 开始执行
main "$@" 
