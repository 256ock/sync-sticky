# Sync Sticky

macOS用シンプル付箋アプリ。iCloud Drive経由で複数Mac間の付箋を同期。

## 機能

- メニューバー常駐（Dockアイコンなし）
- 付箋作成・編集（テキスト、タイトル、カラー）
- ピン留め（最前面固定）表示
- 自動保存 / 手動保存切替
- iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/StickyNotes`) 経由の複数Mac間同期
- 本文中URLをCmd+クリックで開く
- ダーク/ライト表示切替
- ウィンドウ位置・サイズはMacごとにローカル保持（同期対象外）

## 動作環境

- macOS
- Xcode（StickyNotes.xcodeproj）

## ビルド

```
open StickyNotes.xcodeproj
```

Xcodeでビルド・実行。

## 構成

- `StickyNotes/StickyNotesApp.swift` — アプリエントリ、メニューバー制御
- `StickyNotes/StickyNoteStore.swift` — 付箋データの読み書き・同期・監視
- `StickyNotes/StickyNote.swift` — 付箋データモデル
- `StickyNotes/NoteWindowController.swift` — 付箋ウィンドウ管理
- `StickyNotes/NoteEditorView.swift` — 付箋編集UI
- `StickyNotes/LocalFrameStore.swift` — ウィンドウ位置・サイズのローカル保存
- `StickyNotes/LinkAwareTextView.swift` — URL検出対応テキストビュー
