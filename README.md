# SharedHUD TrollStore

全新实现的 TrollStore 全局共享绘制客户端。Android 工程仅作为房间协议、战局字段和绘制规格来源，本项目不复用旧 iOSHUD SwiftUI 代码。

## 架构

- 控制进程：UIKit 设置界面，保存房间、服务器和绘制参数。
- HUD 进程：同一 Mach-O 通过 `-hud` 独立启动；`-check` 检查状态，`-exit` 停止。
- 系统窗口：使用 `SBSAccessibilityWindowHostingController` 托管 QuartzCore context。
- 触摸穿透：透明 `SHHUDWindow` 返回空 hit-test，并设置私有 `_ignoresHitTest`。
- IPC：Darwin Notification 处理 reload、dismiss 和 SpringBoard 重启。
- 数据：连接 `ws://HOST:PORT/ws`，发送 `subscribe[==]ROOM` 与 `ping##TIMESTAMP`，解析 `gameData##`。

## macOS 构建

要求：Xcode 15+、XcodeGen、ldid。

```sh
brew install xcodegen ldid
sh scripts/validate.sh
sh build.sh
```

产物：`dist/SharedHUD.tipa`，通过 TrollStore 安装。私有 SpringBoard API 会随 iOS 版本变化，真机部署目标是 iOS 14 及以上的 TrollStore 环境。

## GitHub Actions

推送整个目录到 Git 仓库，在 Actions 页面运行 `Build SharedHUD TIPA`，完成后下载 `SharedHUD-tipa` artifact。

## 数据兼容

已实现 Android 版本的英雄、野怪、兵线、防御塔解析，坐标空间为 `2400 x 1080`，并保留地图偏移、资源偏移、兵线偏移、地图间距、头像大小和顶部信息调节。
