#!/bin/bash

# Fortytwo Protocol Node 自动监控和重启脚本
# 检测Fortytwo程序是否运行，如果掉线则自动重启

# 配置
FORTYTWO_DIR="$HOME/Fortytwo/fortytwo-console-app-main"
LINUX_SCRIPT="./linux.sh"
CHECK_INTERVAL=30  # 检查间隔（秒）
RESTART_DELAY=10   # 重启前等待时间（秒）
MAX_RESTART_ATTEMPTS=5  # 最大重启尝试次数
LOG_FILE="fortytwo_monitor.log"

# 日志检测配置
CAPSULE_LOGS="$FORTYTWO_DIR/debug/FortytwoCapsule.logs"
ERROR_PATTERN="Request duration already elapsed"
ERROR_THRESHOLD=10  # 错误次数阈值
ERROR_WINDOW=300    # 错误检测时间窗口（秒）

# 新增错误模式配置
ERROR_PATTERN_2="Request effective deadline already elapsed"
ERROR_THRESHOLD_2=5  # 错误次数阈值
ERROR_WINDOW_2=300   # 错误检测时间窗口（秒）

ERROR_PATTERN_3="failed to fetch block"
ERROR_THRESHOLD_3=3  # 错误次数阈值
ERROR_WINDOW_3=300   # 错误检测时间窗口（秒）

# 程序卡住检测配置
STUCK_DETECTION=true
STUCK_CHECK_INTERVAL=60  # 卡住检测间隔（秒）
STUCK_THRESHOLD=300      # 卡住阈值（秒，5分钟无新日志就认为卡住）

# 加载配置文件（如果存在）
CONFIG_FILE="$HOME/.fortytwo-monitor/fortytwo_monitor.conf"
if [ -f "$CONFIG_FILE" ]; then
    log "INFO" "加载配置文件: $CONFIG_FILE"
    source "$CONFIG_FILE"
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 信号处理
cleanup() {
    log "INFO" "收到退出信号，正在停止监控..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# 检查Fortytwo程序是否运行
is_fortytwo_running() {
    # 检查FortytwoCapsule进程
    if pgrep -f "FortytwoCapsule" > /dev/null 2>&1; then
        return 0  # 运行中
    fi
    
    # 检查FortytwoProtocol进程
    if pgrep -f "FortytwoProtocol" > /dev/null 2>&1; then
        return 0  # 运行中
    fi
    
    # 检查linux.sh进程（启动脚本）
    if pgrep -f "linux.sh" > /dev/null 2>&1; then
        return 0  # 运行中
    fi
    
    return 1  # 未运行
}

# 检查日志中的错误
check_log_errors() {
    if [ ! -f "$CAPSULE_LOGS" ]; then
        return 0  # 日志文件不存在，认为没有错误
    fi
    
    # 获取当前时间戳（秒）
    current_time=$(date +%s)
    
    # 检查第一个错误模式
    window_start=$((current_time - ERROR_WINDOW))
    error_count=$(awk -v start="$window_start" -v pattern="$ERROR_PATTERN" '
        function parse_timestamp(timestamp) {
            gsub(/[TZ]/, " ", timestamp)
            gsub(/\./, " ", timestamp)
            split(timestamp, parts, " ")
            date_str = parts[1] " " parts[2] " " parts[3] " " parts[4] " " parts[5]
            return mktime(date_str)
        }
        
        $0 ~ pattern {
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
    
    if [ -n "$error_count" ] && [ "$error_count" -ge "$ERROR_THRESHOLD" ]; then
        log "WARN" "检测到 $error_count 次错误日志: $ERROR_PATTERN (阈值: $ERROR_THRESHOLD)"
        return 1
    fi
    
    # 检查第二个错误模式
    window_start_2=$((current_time - ERROR_WINDOW_2))
    error_count_2=$(awk -v start="$window_start_2" -v pattern="$ERROR_PATTERN_2" '
        function parse_timestamp(timestamp) {
            gsub(/[TZ]/, " ", timestamp)
            gsub(/\./, " ", timestamp)
            split(timestamp, parts, " ")
            date_str = parts[1] " " parts[2] " " parts[3] " " parts[4] " " parts[5]
            return mktime(date_str)
        }
        
        $0 ~ pattern {
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
    
    if [ -n "$error_count_2" ] && [ "$error_count_2" -ge "$ERROR_THRESHOLD_2" ]; then
        log "WARN" "检测到 $error_count_2 次错误日志: $ERROR_PATTERN_2 (阈值: $ERROR_THRESHOLD_2)"
        return 1
    fi
    
    # 检查第三个错误模式
    window_start_3=$((current_time - ERROR_WINDOW_3))
    error_count_3=$(awk -v start="$window_start_3" -v pattern="$ERROR_PATTERN_3" '
        function parse_timestamp(timestamp) {
            gsub(/[TZ]/, " ", timestamp)
            gsub(/\./, " ", timestamp)
            split(timestamp, parts, " ")
            date_str = parts[1] " " parts[2] " " parts[3] " " parts[4] " " parts[5]
            return mktime(date_str)
        }
        
        $0 ~ pattern {
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
    
    if [ -n "$error_count_3" ] && [ "$error_count_3" -ge "$ERROR_THRESHOLD_3" ]; then
        log "WARN" "检测到 $error_count_3 次错误日志: $ERROR_PATTERN_3 (阈值: $ERROR_THRESHOLD_3)"
        return 1
    fi
    
    return 0
}

# 获取Fortytwo进程信息
get_fortytwo_processes() {
    echo "=== Fortytwo进程信息 ==="
    if pgrep -f "FortytwoCapsule" > /dev/null 2>&1; then
        echo "FortytwoCapsule进程:"
        ps aux | grep "FortytwoCapsule" | grep -v grep
    fi
    
    if pgrep -f "FortytwoProtocol" > /dev/null 2>&1; then
        echo "FortytwoProtocol进程:"
        ps aux | grep "FortytwoProtocol" | grep -v grep
    fi
    
    if pgrep -f "linux.sh" > /dev/null 2>&1; then
        echo "linux.sh进程:"
        ps aux | grep "linux.sh" | grep -v grep
        
        # 获取linux.sh进程的PID
        linux_pid=$(pgrep -f "linux.sh" | head -1)
        if [ -n "$linux_pid" ]; then
            echo "linux.sh进程详细信息 (PID: $linux_pid):"
            echo "  进程状态:"
            ps -p "$linux_pid" -o pid,ppid,state,time,pcpu,pmem,cmd
            
            echo "  子进程:"
            pstree -p "$linux_pid" 2>/dev/null || echo "  无法显示进程树"
            
            echo "  进程文件描述符:"
            ls -la /proc/"$linux_pid"/fd 2>/dev/null | head -10 || echo "  无法访问进程文件描述符"
            
            echo "  进程内存使用:"
            cat /proc/"$linux_pid"/status 2>/dev/null | grep -E "(VmSize|VmRSS|VmPeak)" || echo "  无法获取内存信息"
        fi
    fi
}

# 启动Fortytwo程序
start_fortytwo() {
    log "INFO" "正在启动Fortytwo程序..."
    
    if [ ! -d "$FORTYTWO_DIR" ]; then
        log "ERROR" "Fortytwo目录不存在: $FORTYTWO_DIR"
        return 1
    fi
    
    if [ ! -f "$FORTYTWO_DIR/$LINUX_SCRIPT" ]; then
        log "ERROR" "linux.sh脚本不存在: $FORTYTWO_DIR/$LINUX_SCRIPT"
        return 1
    fi
    
    cd "$FORTYTWO_DIR" || {
        log "ERROR" "无法切换到Fortytwo目录"
        return 1
    }
    
    # 检查是否已经有进程在运行
    if is_fortytwo_running; then
        log "WARN" "Fortytwo程序已经在运行，跳过启动"
        return 0
    fi
    
    # 启动程序并在后台运行
    # 使用nohup确保进程在终端关闭后继续运行
    # 将输出重定向到日志文件以便调试
    nohup ./linux.sh > fortytwo_startup.log 2>&1 &
    local startup_pid=$!
    
    log "INFO" "启动脚本PID: $startup_pid"
    
    # 等待程序启动（给更多时间让程序完全启动）
    log "INFO" "等待程序启动..."
    sleep 10
    
    # 检查是否启动成功
    if is_fortytwo_running; then
        log "INFO" "Fortytwo程序启动成功"
        get_fortytwo_processes
        return 0
    else
        log "ERROR" "Fortytwo程序启动失败"
        log "ERROR" "启动日志:"
        if [ -f "fortytwo_startup.log" ]; then
            tail -20 fortytwo_startup.log >> "$LOG_FILE"
        fi
        return 1
    fi
}

# 停止Fortytwo程序
stop_fortytwo() {
    log "INFO" "正在停止Fortytwo程序..."
    
    local killed_count=0
    
    # 先停止FortytwoCapsule进程
    if pkill -f "FortytwoCapsule" > /dev/null 2>&1; then
        killed_count=$((killed_count + 1))
        log "INFO" "已终止FortytwoCapsule进程"
    fi
    
    # 停止FortytwoProtocol进程
    if pkill -f "FortytwoProtocol" > /dev/null 2>&1; then
        killed_count=$((killed_count + 1))
        log "INFO" "已终止FortytwoProtocol进程"
    fi
    
    # 停止linux.sh进程
    if pkill -f "linux.sh" > /dev/null 2>&1; then
        killed_count=$((killed_count + 1))
        log "INFO" "已终止linux.sh进程"
    fi
    
    if [ $killed_count -gt 0 ]; then
        log "INFO" "已终止 $killed_count 个Fortytwo相关进程"
        sleep 3  # 等待进程完全终止
    else
        log "INFO" "未找到运行中的Fortytwo进程"
    fi
    
    return 0
}

# 重启Fortytwo程序
restart_fortytwo() {
    log "INFO" "开始重启Fortytwo程序..."
    
    if stop_fortytwo; then
        log "INFO" "等待 $RESTART_DELAY 秒后重启..."
        sleep $RESTART_DELAY
        
        if start_fortytwo; then
            log "INFO" "Fortytwo程序重启成功"
            return 0
        else
            log "ERROR" "Fortytwo程序重启失败"
            return 1
        fi
    else
        log "ERROR" "无法停止Fortytwo程序"
        return 1
    fi
}

# 检查程序是否卡住（长时间无新日志）
check_if_stuck() {
    if [ ! -f "$CAPSULE_LOGS" ]; then
        return 0  # 日志文件不存在，认为没有卡住
    fi
    
    # 获取当前时间戳（秒）
    current_time=$(date +%s)
    
    # 获取日志文件的最后修改时间
    if [ -f "$CAPSULE_LOGS" ]; then
        last_modified=$(stat -c %Y "$CAPSULE_LOGS" 2>/dev/null || echo "0")
        time_diff=$((current_time - last_modified))
        
        if [ $time_diff -gt $STUCK_THRESHOLD ]; then
            log "WARN" "程序可能卡住: 日志文件 $time_diff 秒未更新 (阈值: $STUCK_THRESHOLD 秒)"
            return 1
        fi
    fi
    
    # 检查最后一条日志的时间
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
        time_diff=$((current_time - last_log_time))
        if [ $time_diff -gt $STUCK_THRESHOLD ]; then
            log "WARN" "程序可能卡住: 最后日志 $time_diff 秒前 (阈值: $STUCK_THRESHOLD 秒)"
            return 1
        fi
    fi
    
    return 0
}

# 主监控函数
monitor() {
    log "INFO" "开始监控Fortytwo程序..."
    log "INFO" "Fortytwo目录: $FORTYTWO_DIR"
    log "INFO" "检查间隔: $CHECK_INTERVAL 秒"
    log "INFO" "最大重启尝试次数: $MAX_RESTART_ATTEMPTS"
    log "INFO" "错误检测阈值:"
    log "INFO" "  - $ERROR_PATTERN: $ERROR_THRESHOLD 次/$ERROR_WINDOW 秒"
    log "INFO" "  - $ERROR_PATTERN_2: $ERROR_THRESHOLD_2 次/$ERROR_WINDOW_2 秒"
    log "INFO" "  - $ERROR_PATTERN_3: $ERROR_THRESHOLD_3 次/$ERROR_WINDOW_3 秒"
    log "INFO" "卡住检测: $STUCK_THRESHOLD 秒无新日志"
    
    local consecutive_failures=0
    local restart_attempts=0
    local log_error_restart=false
    local stuck_check_counter=0
    
    while true; do
        local should_restart=false
        local restart_reason=""
        
        # 检查进程是否运行
        if is_fortytwo_running; then
            consecutive_failures=0
            
            # 检查日志错误
            if check_log_errors; then
                # 检查程序是否卡住（每60秒检查一次）
                stuck_check_counter=$((stuck_check_counter + 1))
                if [ $stuck_check_counter -ge $((STUCK_CHECK_INTERVAL / CHECK_INTERVAL)) ]; then
                    stuck_check_counter=0
                    if check_if_stuck; then
                        log "INFO" "Fortytwo程序运行正常"
                    else
                        log "WARN" "检测到程序卡住，需要重启"
                        should_restart=true
                        restart_reason="程序卡住"
                    fi
                else
                    log "INFO" "Fortytwo程序运行正常"
                fi
            else
                log "WARN" "检测到日志错误，需要重启"
                should_restart=true
                restart_reason="日志错误"
                log_error_restart=true
            fi
        else
            consecutive_failures=$((consecutive_failures + 1))
            log "WARN" "Fortytwo程序未运行 (连续失败 $consecutive_failures 次)"
            
            # 如果连续失败次数达到阈值，尝试重启
            if [ $consecutive_failures -ge 2 ]; then
                should_restart=true
                restart_reason="进程未运行"
            fi
        fi
        
        # 执行重启逻辑
        if [ "$should_restart" = true ]; then
            if [ $restart_attempts -lt $MAX_RESTART_ATTEMPTS ]; then
                log "INFO" "准备重启Fortytwo程序 (原因: $restart_reason)"
                if restart_fortytwo; then
                    consecutive_failures=0
                    restart_attempts=0  # 重置重启计数
                    log_error_restart=false
                    stuck_check_counter=0
                    log "INFO" "Fortytwo程序重启成功"
                else
                    restart_attempts=$((restart_attempts + 1))
                    log "ERROR" "重启失败 (尝试 $restart_attempts/$MAX_RESTART_ATTEMPTS)"
                fi
            else
                log "ERROR" "已达到最大重启尝试次数 ($MAX_RESTART_ATTEMPTS)，停止自动重启"
                break
            fi
        fi
        
        # 等待下次检查
        sleep $CHECK_INTERVAL
    done
}

# 主函数
main() {
    echo -e "${BLUE}Fortytwo Protocol Node 自动监控脚本${NC}"
    echo -e "${BLUE}==================================================${NC}"
    
    # 检查是否在WSL环境中
    if [ -f "/proc/version" ] && grep -q "microsoft" /proc/version; then
        echo -e "${GREEN}检测到WSL环境${NC}"
    else
        echo -e "${YELLOW}警告: 此脚本设计用于WSL环境${NC}"
    fi
    
    # 检查依赖
    if ! command -v pgrep > /dev/null 2>&1; then
        echo -e "${RED}错误: 缺少pgrep命令${NC}"
        exit 1
    fi
    
    if ! command -v pkill > /dev/null 2>&1; then
        echo -e "${RED}错误: 缺少pkill命令${NC}"
        exit 1
    fi
    
    # 开始监控
    monitor
}

# 运行主函数
main "$@" 