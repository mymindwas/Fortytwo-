# Fortytwo节点

Fortytwo开发网络是去中心化、行星级智能开发的第一阶段。它连接社区拥有的节点，这些节点在 PC 和 Mac 等消费设备上运行小型语言模型。每个节点贡献闲置的计算能力，创建一个分布式网络，随着更多参与者的加入而不断改进。

该开发网络运行在 Monad 测试网（一个与 Layer 1 EVM 兼容的区块链）上，并作为结算层。节点性能和参与数据均记录在链上，以确保透明度和安全性。

运行节点：

填写节点运营商表格。https://tally.so/r/wQzVQk

如果选择此选项，您将收到一封包含激活码的电子邮件。您需要按照提供的说明设置节点时输入此激活码。

一旦您的节点成功运行，您将继续参与网络并有资格获得额外的代币掉落。

正确操作的节点将有资格根据其持续参与和表现获得 Fortytwo 奖励。

使用说明：

## 1.先参考教程，安装官方文件（https://docs.fortytwo.network/docs/quick-start）	
```bash
mkdir -p ~/Fortytwo && cd ~/Fortytwo
```
```bash
curl -L -o fortytwo-console-app.zip https://github.com/Fortytwo-Network/fortytwo-console-app/archive/refs/heads/main.zip
```
```bash
unzip fortytwo-console-app.zip
```
```bash
cd fortytwo-console-app-main
```
```bash
chmod +x linux.sh && ./linux.sh
```
按官方教程导入安装好并下载好模型。

## 2.重启节点（新建一个screen界面，如果使用的是windows则重新打开一个wsl):
```bash
cd
```
```bash
chmod +x install_monitor.sh
```
```bash
chmod +x fortytwo_monitor.sh
```
```bash
./install_monitor.sh
```
```bash
.fortytwo-monitor/start_monitor.sh
```

关掉原来的官方教程运行的Ubuntu界面，新界面中看到
![image](https://github.com/user-attachments/assets/5b82829a-00e0-4abc-b368-7031cbb288fb)

说明运行成功

## 3.查看日志
```bash
tail -f ~/Fortytwo/fortytwo-console-app-main/fortytwo_startup.log
```
```bash
tail -20 ~/Fortytwo/fortytwo-console-app-main/fortytwo_startup.log
```

## 工作原理

1. **精确进程检测**: 分别检测FortytwoCapsule、FortytwoProtocol和linux.sh进程
2. **状态监控**: 每30秒检查一次程序状态
3. **自动重启**: 连续2次检测失败后自动重启
4. **智能重试**: 最多重试5次，避免无限重启
5. **详细日志**: 记录启动过程和监控状态
6. **日志错误检测**: 监控FortytwoCapsule日志中的错误模式并自动重启



