# openfortivpn-gui

[English](README.md) | [繁體中文](README.zh-TW.md)

一個原生 macOS SwiftUI 圖形介面，包裝 [openfortivpn](https://github.com/adrienverge/openfortivpn)，支援多組設定檔、選單列狀態顯示、自動重新連線，以及從 FortiClient 單向匯入設定檔。

介面支援英文與繁體中文，會自動跟隨 Mac 的系統語言設定（**系統設定 → 一般 → 語言與地區**）。

> **需要事先安裝好 `openfortivpn`**（例如透過 Homebrew：`brew install openfortivpn`）。這個 app 只是它的 GUI 外殼，不是替代品——如果你的 Mac 上沒有 `openfortivpn` 執行檔，這個 app 就沒辦法運作。

## 需求

- macOS 14 以上
- 透過 Homebrew 安裝的 `openfortivpn`（`brew install openfortivpn`）
- Swift 工具鏈（裝 Xcode Command Line Tools 就夠了，不需要完整版 Xcode）

## 安裝（一般使用）

```
./Scripts/install.sh
```

這個指令會編譯 release 版本，安裝成 `/Applications/openfortivpn-gui.app`（含圖示），並啟動它。之後就跟一般 Mac App 一樣，可以從 Launchpad／Spotlight／Dock 開啟，不需要再重跑任何 script。一般管理員帳號不需要 `sudo`，因為預設 `/Applications` 對 `admin` 群組是可寫的。之後想更新到最新版程式碼，重新執行 `install.sh` 即可。

第一次啟動時，app 會跳出一次系統管理員授權，讓 `openfortivpn` 之後每次連線都能以 root 身分執行、不用每次都輸入密碼（透過一條範圍限定的 `/etc/sudoers.d/openfortivpn-gui` 規則）。

這個 app 沒有簽章也沒有經過公證，第一次開啟很可能會被 Gatekeeper 擋下來——放行方式請見下方[安全性](#安全性)章節。

## 建置與執行（開發用）

```
./Scripts/run.sh
```

這個指令會編譯 debug 版本，並把它包成一個最小的 `.app` bundle 用 `open` 啟動，不會安裝到 `/Applications`——適合修改程式碼時快速重跑。請用這個（或 `install.sh`）而不是直接 `swift run`——直接跑沒包裝過的執行檔會跳過 LaunchServices 註冊，導致 SwiftUI 的 `TextField` 打字、複製貼上等跟文字輸入系統有關的互動都會壞掉。

## 安全性

- 這個 app **沒有經過任何獨立的安全稽核或審查**。
- **沒有簽章、也沒有經過公證**——第一次執行時 macOS Gatekeeper 很可能會跳警告（「無法打開，因為無法驗證開發者」）。放行方式：**系統設定 → 隱私權與安全性**，往下捲到被擋下的 app 提示，點 **強制打開**，接著在跳出的對話框裡再次確認。
- 會要求你做一次系統管理員授權，寫入一條 sudoers 規則讓 `openfortivpn` 可以免密碼以 root 權限執行（範圍限定在這一個執行檔，不是開放一般性的 root 存取——實際寫入的內容可以看 `Sources/openfortivpn-gui/Services/PrivilegeService.swift`）。
- 密碼一律存在 macOS Keychain，不會以明文寫在硬碟上。
- 如果你比較在意安全性，建議自己看過原始碼再授權——專案不大，一次看完不是問題。使用風險自負。

## 授權條款

[MIT](LICENSE)
