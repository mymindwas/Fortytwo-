使用说明：

1.先参考教程，安装官方文件（https://docs.fortytwo.network/docs/quick-start）	

mkdir -p ~/Fortytwo && cd ~/Fortytwo

curl -L -o fortytwo-console-app.zip https://github.com/Fortytwo-Network/fortytwo-console-app/archive/refs/heads/main.zip

unzip fortytwo-console-app.zip

cd fortytwo-console-app-main

chmod +x linux.sh && ./linux.sh

按官方教程导入安装好并下载好模型。

2.重启节点（新建一个screen界面，如果使用的是windows则重新打开一个wsl)
cd

chmod +x install_monitor.sh

chmod +x fortytwo_monitor.sh

./install_monitor.sh  

.fortytwo-monitor/start_monitor.sh

关掉原来的运行的Ubuntu，看到
![image](https://github.com/user-attachments/assets/5b82829a-00e0-4abc-b368-7031cbb288fb)

说明运行成功

3.查看日志

tail -f ~/Fortytwo/fortytwo-console-app-main/fortytwo_startup.log

tail -20 ~/Fortytwo/fortytwo-console-app-main/fortytwo_startup.log

## 工作原理

1. **精确进程检测**: 分别检测FortytwoCapsule、FortytwoProtocol和linux.sh进程
2. **状态监控**: 每30秒检查一次程序状态
3. **自动重启**: 连续2次检测失败后自动重启
4. **智能重试**: 最多重试5次，避免无限重启
5. **详细日志**: 记录启动过程和监控状态
6. **日志错误检测**: 监控FortytwoCapsule日志中的错误模式并自动重启



