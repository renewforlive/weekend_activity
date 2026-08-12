# 週末遊

## 環境

- 正式版：`prod` flavor，套件 ID 為 `com.my.weekendplay`，連線正式 Supabase。
- 測試版：`dev` flavor，套件 ID 為 `com.my.weekendplay.dev`，必須提供獨立測試 Supabase 的 URL 與 publishable key；未設定時會顯示設定頁，絕不連線正式資料。

建置測試版：

```powershell
.\tool\build-dev.ps1 -SupabaseUrl 'https://your-dev-project.supabase.co' -SupabasePublishableKey 'sb_publishable_...'
```

建置正式版：

```powershell
.\tool\build-prod.ps1
```

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
