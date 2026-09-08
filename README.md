# 王者共享 iOS

这是 Android `hai` 的 iOS 应用内 HUD 版本，包含：

- 房间 WebSocket 连接与自动重连
- 英雄、野怪资源、兵线、防御塔实时绘制
- 敌方顶部英雄信息与技能冷却
- 显示开关、位置/间隔/头像/透明度调节
- 深色金色主界面、关于页与校准预览

iOS 的公开 API 不允许普通 App 像 Android 一样在其他游戏上方创建透明触摸穿透窗口，因此 HUD 在本应用内显示。若要做录屏/直播合成，应另加 ReplayKit Broadcast Upload Extension，将 HUD 合成到广播帧中。

## 打开

用 Xcode 打开 `KingShared.xcodeproj`，选择 iOS 16 或更高版本的模拟器/真机运行。WebSocket 地址与 Android 保持一致：`ws://king.weilua.top:8888/ws`。

## Windows 用户：GitHub 编译

把整个 `kingios` 目录上传到 GitHub 仓库并推送到 `main` 或 `master`，或者在 GitHub Actions 页面手动运行 `Build iOS`。工作流会在 GitHub macOS runner 上完成无签名编译，并生成：

- `KingShared-unsigned-ipa`：可下载的未签名 IPA
- `KingShared-app`：原始 `.app` 包

未签名 IPA 不能直接安装，需要用 TrollStore 或其他自签工具重新签名。无需在 Windows 本机安装 Xcode。
