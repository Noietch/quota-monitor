# 号池额度监控

一个原生 macOS 菜单栏小组件，用于监控号池账号的 5h / 7d 额度。

## 功能

- 菜单栏显示当前可用账号数，例如 `3/7`
- 顶部显示号池最早恢复时间，并展示每个账号的 5h / 7d 使用率和各自恢复时间
- 1、5、15 或 30 分钟自动刷新，也可手动刷新
- 请求失败时保留最近一次成功数据
- API Token 仅存储在 macOS Keychain，不写入配置文件或缓存
- 原生 SwiftUI / AppKit，无第三方依赖

## 构建与运行

```bash
./build.sh
open QuotaMonitor.app
```

首次点击菜单栏的服务器图标，在设置页填入 API Token。默认接口为：

```text
https://sub2api.labuta.diy/quota/v1/group
```

应用要求 macOS 13 或更新版本，发布包同时支持 Apple Silicon 和 Intel。这里只使用 Command Line Tools 即可构建菜单栏版本，不要求完整 Xcode。

开发时可运行 `QuotaMonitor.app/Contents/MacOS/QuotaMonitor --preview`，在普通窗口中检查弹窗布局；正常启动不会显示该窗口。
