#!/bin/bash

# Fortytwo监控脚本安装程序

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Fortytwo Protocol Node 监控脚本安装程序${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查是否在WSL环境中
if [ -f "/proc/version" ] && grep -q "microsoft" /proc/version; then
    echo -e "${GREEN}✓ 检测到WSL环境${NC}"
else
    echo -e "${YELLOW}⚠ 警告: 此脚本设计用于WSL环境${NC}"
fi

# 获取当前用户
CURRENT_USER=$(whoami)
echo -e "${BLUE}当前用户: $CURRENT_USER${NC}"

# 检查依赖
echo -e "${BLUE}检查系统依赖...${NC}"

if ! command -v pgrep > /dev/null 2>&1; then
    echo -e "${RED}✗ 错误: 缺少pgrep命令${NC}"
    exit 1
fi

if ! command -v pkill > /dev/null 2>&1; then
    echo -e "${RED}✗ 错误: 缺少pkill命令${NC}"
    exit 1
fi

if ! command -v systemctl > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ 警告: 缺少systemctl命令，将无法安装为系统服务${NC}"
    SYSTEMD_AVAILABLE=false
else
    echo -e "${GREEN}✓ systemctl可用${NC}"
    SYSTEMD_AVAILABLE=true
fi

echo -e "${GREEN}✓ 所有依赖检查通过${NC}"

# 设置脚本权限
echo -e "${BLUE}设置脚本权限...${NC}"
chmod +x fortytwo_monitor.sh
chmod +x fortytwo_monitor.py
echo -e "${GREEN}✓ 脚本权限设置完成${NC}"

# 创建配置目录
CONFIG_DIR="$HOME/.fortytwo-monitor"
mkdir -p "$CONFIG_DIR"
echo -e "${GREEN}✓ 配置目录创建完成: $CONFIG_DIR${NC}"

# 复制配置文件
cp fortytwo_monitor.sh "$CONFIG_DIR/"
cp fortytwo_monitor.py "$CONFIG_DIR/"

# 复制进程查看脚本（如果存在）
if [ -f "view_process.sh" ]; then
    cp view_process.sh "$CONFIG_DIR/"
    chmod +x "$CONFIG_DIR/view_process.sh"
    echo -e "${GREEN}✓ 进程查看脚本复制完成${NC}"
fi

# 复制配置文件（如果存在）
if [ -f "fortytwo_monitor.conf" ]; then
    cp fortytwo_monitor.conf "$CONFIG_DIR/"
    echo -e "${GREEN}✓ 配置文件复制完成${NC}"
else
    # 创建默认配置文件
    cat > "$CONFIG_DIR/fortytwo_monitor.conf" << 'EOF'
# Fortytwo监控脚本配置文件
# 修改此文件来自定义监控参数

# 基本配置
FORTYTWO_DIR="$HOME/Fortytwo/fortytwo-console-app-main"
LINUX_SCRIPT="./linux.sh"
CHECK_INTERVAL=30  # 检查间隔（秒）
RESTART_DELAY=10   # 重启前等待时间（秒）
MAX_RESTART_ATTEMPTS=5  # 最大重启尝试次数

# 日志检测配置
CAPSULE_LOGS="$FORTYTWO_DIR/debug/FortytwoCapsule.logs"

# 错误模式1: Request duration already elapsed
ERROR_PATTERN="Request duration already elapsed"
ERROR_THRESHOLD=10  # 错误次数阈值（5分钟内出现10次错误就重启）
ERROR_WINDOW=300    # 错误检测时间窗口（秒，5分钟）

# 错误模式2: Request effective deadline already elapsed
ERROR_PATTERN_2="Request effective deadline already elapsed"
ERROR_THRESHOLD_2=5  # 错误次数阈值（5分钟内出现5次错误就重启）
ERROR_WINDOW_2=300   # 错误检测时间窗口（秒，5分钟）

# 错误模式3: failed to fetch block
ERROR_PATTERN_3="failed to fetch block"
ERROR_THRESHOLD_3=3  # 错误次数阈值（5分钟内出现3次错误就重启）
ERROR_WINDOW_3=300   # 错误检测时间窗口（秒，5分钟）

# 程序卡住检测配置
STUCK_DETECTION=true
STUCK_CHECK_INTERVAL=60  # 卡住检测间隔（秒）
STUCK_THRESHOLD=300      # 卡住阈值（秒，5分钟无新日志就认为卡住）
EOF
    echo -e "${GREEN}✓ 默认配置文件创建完成${NC}"
fi

# 安装systemd服务（如果可用）
if [ "$SYSTEMD_AVAILABLE" = true ]; then
    echo -e "${BLUE}安装systemd服务...${NC}"
    
    # 复制服务文件到用户目录
    USER_SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$USER_SERVICE_DIR"
    
    # 修改服务文件中的路径
    sed "s|%h|$HOME|g; s|%i|$CURRENT_USER|g" fortytwo-monitor.service > "$USER_SERVICE_DIR/fortytwo-monitor.service"
    
    # 重新加载systemd用户单元
    systemctl --user daemon-reload
    
    # 启用服务
    systemctl --user enable fortytwo-monitor.service
    
    echo -e "${GREEN}✓ systemd服务安装完成${NC}"
    echo -e "${BLUE}服务状态:${NC}"
    systemctl --user status fortytwo-monitor.service --no-pager -l
    
    echo -e "${YELLOW}提示: 使用以下命令管理服务:${NC}"
    echo -e "  启动服务: systemctl --user start fortytwo-monitor.service"
    echo -e "  停止服务: systemctl --user stop fortytwo-monitor.service"
    echo -e "  查看状态: systemctl --user status fortytwo-monitor.service"
    echo -e "  查看日志: journalctl --user -u fortytwo-monitor.service -f"
else
    echo -e "${YELLOW}⚠ 无法安装systemd服务，请手动运行监控脚本${NC}"
fi

# 创建启动脚本
cat > "$CONFIG_DIR/start_monitor.sh" << 'EOF'
#!/bin/bash
# 启动Fortytwo监控脚本

cd "$(dirname "$0")"

echo "启动Fortytwo监控脚本..."
echo "按 Ctrl+C 停止监控"

# 运行监控脚本
./fortytwo_monitor.sh
EOF

chmod +x "$CONFIG_DIR/start_monitor.sh"

# 创建停止脚本
cat > "$CONFIG_DIR/stop_monitor.sh" << 'EOF'
#!/bin/bash
# 停止Fortytwo监控脚本

echo "停止Fortytwo监控脚本..."

# 停止systemd服务（如果可用）
if command -v systemctl > /dev/null 2>&1; then
    systemctl --user stop fortytwo-monitor.service 2>/dev/null
fi

# 终止监控进程
pkill -f "fortytwo_monitor.sh"
pkill -f "fortytwo_monitor.py"

echo "监控脚本已停止"
EOF

chmod +x "$CONFIG_DIR/stop_monitor.sh"

# 创建状态检查脚本
cat > "$CONFIG_DIR/status.sh" << 'EOF'
#!/bin/bash
# 检查Fortytwo监控状态

echo "=== Fortytwo监控状态 ==="

# 检查systemd服务状态
if command -v systemctl > /dev/null 2>&1; then
    echo "Systemd服务状态:"
    systemctl --user status fortytwo-monitor.service --no-pager -l
    echo
fi

# 检查监控进程
echo "监控进程状态:"
if pgrep -f "fortytwo_monitor" > /dev/null; then
    echo "✓ 监控脚本正在运行"
    ps aux | grep "fortytwo_monitor" | grep -v grep
else
    echo "✗ 监控脚本未运行"
fi

echo

# 检查Fortytwo程序状态
echo "Fortytwo程序状态:"
fortytwo_running=false

if pgrep -f "FortytwoCapsule" > /dev/null; then
    echo "✓ FortytwoCapsule进程正在运行"
    ps aux | grep "FortytwoCapsule" | grep -v grep
    fortytwo_running=true
fi

if pgrep -f "FortytwoProtocol" > /dev/null; then
    echo "✓ FortytwoProtocol进程正在运行"
    ps aux | grep "FortytwoProtocol" | grep -v grep
    fortytwo_running=true
fi

if pgrep -f "linux.sh" > /dev/null; then
    echo "✓ linux.sh启动脚本正在运行"
    ps aux | grep "linux.sh" | grep -v grep
    fortytwo_running=true
fi

if [ "$fortytwo_running" = false ]; then
    echo "✗ Fortytwo程序未运行"
fi

echo

# 显示日志文件
if [ -f "fortytwo_monitor.log" ]; then
    echo "最近的监控日志记录:"
    tail -10 fortytwo_monitor.log
else
    echo "未找到监控日志文件"
fi

echo

# 显示Fortytwo启动日志
if [ -f "fortytwo_startup.log" ]; then
    echo "最近的Fortytwo启动日志:"
    tail -5 fortytwo_startup.log
else
    echo "未找到Fortytwo启动日志文件"
fi

echo

# 检查FortytwoCapsule日志中的错误
CAPSULE_LOGS="debug/FortytwoCapsule.logs"
if [ -f "$CAPSULE_LOGS" ]; then
    echo "最近的FortytwoCapsule日志:"
    tail -10 "$CAPSULE_LOGS"
    
    echo
    echo "错误统计 (最近5分钟):"
    current_time=$(date +%s)
    window_start=$((current_time - 300))
    
    # 统计第一个错误模式
    error_count=$(awk -v start="$window_start" '
        function parse_timestamp(timestamp) {
            gsub(/[TZ]/, " ", timestamp)
            gsub(/\./, " ", timestamp)
            split(timestamp, parts, " ")
            date_str = parts[1] " " parts[2] " " parts[3] " " parts[4] " " parts[5]
            return mktime(date_str)
        }
        
        /Request duration already elapsed/ {
            timestamp = $1
            log_time = parse_timestamp(timestamp)
            if (log_time >= start) {
                count++
            }
        }
        END {
            print count
        }
    ' "$CAPSULE_LOGS")
    
    # 统计第二个错误模式
    error_count_2=$(awk -v start="$window_start" '
        function parse_timestamp(timestamp) {
            gsub(/[TZ]/, " ", timestamp)
            gsub(/\./, " ", timestamp)
            split(timestamp, parts, " ")
            date_str = parts[1] " " parts[2] " " parts[3] " " parts[4] " " parts[5]
            return mktime(date_str)
        }
        
        /Request effective deadline already elapsed/ {
            timestamp = $1
            log_time = parse_timestamp(timestamp)
            if (log_time >= start) {
                count++
            }
        }
        END {
            print count
        }
    ' "$CAPSULE_LOGS")
    
    # 统计第三个错误模式
    error_count_3=$(awk -v start="$window_start" '
        function parse_timestamp(timestamp) {
            gsub(/[TZ]/, " ", timestamp)
            gsub(/\./, " ", timestamp)
            split(timestamp, parts, " ")
            date_str = parts[1] " " parts[2] " " parts[3] " " parts[4] " " parts[5]
            return mktime(date_str)
        }
        
        /failed to fetch block/ {
            timestamp = $1
            log_time = parse_timestamp(timestamp)
            if (log_time >= start) {
                count++
            }
        }
        END {
            print count
        }
    ' "$CAPSULE_LOGS")
    
    if [ -z "$error_count" ]; then error_count=0; fi
    if [ -z "$error_count_2" ]; then error_count_2=0; fi
    if [ -z "$error_count_3" ]; then error_count_3=0; fi
    
    echo "  - Request duration already elapsed: $error_count 次"
    echo "  - Request effective deadline already elapsed: $error_count_2 次"
    echo "  - failed to fetch block: $error_count_3 次"
    
    total_errors=$((error_count + error_count_2 + error_count_3))
    if [ $total_errors -eq 0 ]; then
        echo "✓ 最近5分钟内无错误日志"
    else
        echo "⚠ 最近5分钟内检测到总计 $total_errors 次错误日志"
    fi
    
    echo
    echo "卡住检测状态:"
    if [ -f "$CAPSULE_LOGS" ]; then
        current_time=$(date +%s)
        last_modified=$(stat -c %Y "$CAPSULE_LOGS" 2>/dev/null || echo "0")
        time_diff=$((current_time - last_modified))
        
        echo "  - 日志文件最后修改: $time_diff 秒前"
        
        last_log_time=$(tail -1 "$CAPSULE_LOGS" 2>/dev/null | awk '
            function parse_timestamp(timestamp) {
                gsub(/[TZ]/, " ", timestamp)
                gsub(/\./, " ", timestamp)
                split(timestamp, parts, " ")
                date_str = parts[1] " " parts[2] " " parts[3] " " parts[4] " " parts[5]
                return mktime(date_str)
            }
            
            {
                timestamp = $1
                log_time = parse_timestamp(timestamp)
                print log_time
            }
        ')
        
        if [ -n "$last_log_time" ] && [ "$last_log_time" -gt 0 ]; then
            log_time_diff=$((current_time - last_log_time))
            echo "  - 最后日志时间: $log_time_diff 秒前"
            
            if [ $log_time_diff -gt 300 ]; then
                echo "  ⚠ 程序可能卡住 (超过5分钟无新日志)"
            else
                echo "  ✓ 程序运行正常"
            fi
        else
            echo "  - 无法解析最后日志时间"
        fi
    else
        echo "  - 日志文件不存在"
    fi
else
    echo "未找到FortytwoCapsule日志文件"
fi
EOF

chmod +x "$CONFIG_DIR/status.sh"

echo -e "${GREEN}✓ 安装完成！${NC}"
echo
echo -e "${BLUE}使用方法:${NC}"
echo -e "1. 手动启动监控: $CONFIG_DIR/start_monitor.sh"
echo -e "2. 手动停止监控: $CONFIG_DIR/stop_monitor.sh"
echo -e "3. 查看监控状态: $CONFIG_DIR/status.sh"
echo -e "4. 查看进程详情: $CONFIG_DIR/view_process.sh"

if [ "$SYSTEMD_AVAILABLE" = true ]; then
    echo -e "5. 启动系统服务: systemctl --user start fortytwo-monitor.service"
    echo -e "6. 停止系统服务: systemctl --user stop fortytwo-monitor.service"
    echo -e "7. 查看服务日志: journalctl --user -u fortytwo-monitor.service -f"
fi

echo
echo -e "${YELLOW}配置文件位置: $CONFIG_DIR${NC}"
echo -e "${YELLOW}日志文件: $CONFIG_DIR/fortytwo_monitor.log${NC}"
echo
echo -e "${GREEN}安装完成！现在可以开始监控Fortytwo程序了。${NC}" 