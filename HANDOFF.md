# 周末遊專案交接

最後更新：2026-08-24  
主要分支：`dev`

## 專案概覽

Flutter 應用程式，名稱為「周末遊」。支援 Android、iOS 與 Web；Web 目前部署在 Firebase Hosting，帳號、個人資料、招募、行程等資料使用 Supabase。

主要功能：

- 景點、展覽、登山步道、露營場、密室逃脫、桌遊店探索。
- 首頁「這個周末推薦你去這裡玩」依所選縣市隨機推薦景點、展覽、登山、露營、桌遊、密室逃脫。
- 行程、招募、已預約、個人頁、頭像與興趣標籤。
- 招募申請與審核通知；已確認成團活動會進入已預約。
- Email 登入、記住帳號與生物辨識登入流程。

## 重要檔案

- `lib/data/app_state.dart`：主要 App 狀態、各類探索資料載入、行程與招募操作。
- `lib/pages/activities_page.dart`：首頁週末推薦與「自己探索」頁。
- `assets/data/`：本地景點、步道、露營、密室逃脫、桌遊店資料。
- `assets/data/escape_rooms.json`：已核實官方連結的密室逃脫場館。
- `assets/data/board_game_venues.json`：桌遊店資料；目前含台北、新北、桃園、台中、台南、嘉義市、高雄。
- `assets/images/weekend_recommendations/`：首頁推薦卡的預設圖片。
- `supabase/`：資料庫 migration 與 Edge Function 相關檔案。
- `firebase.json`：Web Hosting 設定，部署目錄為 `build/web`。

## 環境

| 環境 | 用途 | Supabase |
| --- | --- | --- |
| `dev` | 測試版 | 獨立測試 Supabase 專案；URL 與 publishable key 以 `--dart-define` 傳入 |
| `prod` | 正式版 | 正式 Supabase 設定在 `lib/services/supabase_config.dart` |

切勿把 `APP_ENV=dev` 編譯出的 bundle 部署到正式網址，否則介面會顯示「周末遊 測試版」且連到測試資料庫。

## Web 部署

先登入 Firebase CLI，並確認 `tool/firebase.exe` 可用。

### 測試版

```powershell
flutter build web --release `
  --dart-define=APP_ENV=dev `
  --dart-define=SUPABASE_DEV_URL=https://<dev-project>.supabase.co `
  --dart-define=SUPABASE_DEV_PUBLISHABLE_KEY=<dev-publishable-key>

.\tool\firebase.exe hosting:channel:deploy test --project weekendplay-web-prod --expires 30d
```

測試網址：`https://weekendplay-web-prod--test-dme7ddcj.web.app`

### 正式版

```powershell
flutter build web --release --dart-define=APP_ENV=prod
.\tool\firebase.exe deploy --only hosting --project weekendplay-web-prod
```

正式網址：`https://weekendplay-web-prod.web.app`

## 開發原則

- 新功能先部署測試版，經使用者確認才部署正式版。
- 不需自動 build 手機版；僅在使用者明確提出時進行。
- 店家／場館資料以官方網站、官方帳號或可信公開資料核實；只保存名稱、地址、自寫簡介與官方連結。不要複製第三方網站文字、圖片或評價。
- 新縣市暫無足夠可核實資料時顯示空狀態，不要為湊數加入不確定店家。
- `outputs/` 為本機輸出資料夾，通常不提交。

## Git 工作方式

```powershell
git switch dev
git pull origin dev
flutter pub get
```

完成驗收後，先檢查 `git status`；不要提交 `build/`、Flutter 快取或個人輸出檔。將功能相關程式、資產與資料檔提交至 `dev` 並推送：

```powershell
git add <相關檔案>
git commit -m "feat: <描述>"
git push origin dev
```

## 近期完成

- 新增密室逃脫探索、行程整合與首頁推薦。
- 新增桌遊探索、詳情、行程整合、首頁推薦與預設背景圖。
- 桌遊首批擴至新北與桃園，並已部署正式版。

## 建議後續工作

1. 持續補齊其餘縣市的桌遊店與密室逃脫資料。
2. 為本地店家資料建立更新日期與資料來源管理流程。
3. 上架前檢視隱私權政策、使用者條款、帳號註銷與通知權限流程。
4. 若增加付費功能，先完成商業規則、App Store／Google Play 內購與後端驗證設計。
