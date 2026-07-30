# 志工小時數紀錄系統

這是一個用來管理學生、活動與志工時數的個人學習專案。前端使用 PureScript 與 Halogen，後端使用 Java、Spring Boot 與 JDBC，正式資料庫部署在 Neon PostgreSQL。

## 線上版本

- 前端：https://volunteer-record-system-frontend.onrender.com
- 後端：https://volunteer-record-system.onrender.com

Render 免費服務休眠後第一次啟動可能需要等待十幾秒，前端清單會在後端喚醒後載入。

## 目前功能

- 新增、修改、刪除與排序學生資料
- 依學期管理學生座位
- 新增、修改、刪除與拖曳排序活動
- 管理活動類型與標籤顏色
- 一次替多位學生建立時數紀錄
- 分頁載入、複製、選取與批次刪除時數紀錄
- 暫存尚未送出的時數輸入內容
- 下載包含主要資料表的 Excel 備份
- 依日期記錄當日主要活動
- 查看學生時數比較、每日總時數折線圖與活動排名

## 主要頁面

前端使用 hash routing：

- `/#/`：首頁
- `/#/master-data/students`：修改學生資料
- `/#/master-data/activities`：修改活動資料
- `/#/records`：輸入時數條與登錄歷史
- `/#/summary`：查看資料庫與統計
- `/#/daily-activity`：添加當日活動

## 技術架構

- 前端：PureScript 0.15、Halogen、Routing Duplex、Affjax
- 後端：Java 21、Spring Boot、Spring JDBC
- 資料庫：PostgreSQL，本機與 Neon 各自獨立
- Excel：Apache POI
- 部署：Render 前端服務、Render 後端 Docker、Neon PostgreSQL

詳細說明：

- [API.md](API.md)
- [DATABASE.md](DATABASE.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [AGENTS.md](AGENTS.md)

## 本機啟動

### 1. 準備資料庫

建立本機 PostgreSQL 資料庫 `volunteer_record_system`，並確認目前需要的資料表與 migration 已完成。`backend/sql/` 是歷史手動 migration，執行前請先閱讀 [DATABASE.md](DATABASE.md)，不要不加判斷地全部重跑。

後端預設連線設定：

```text
URL: jdbc:postgresql://localhost:5432/volunteer_record_system
username: postgres
password: 空白
```

也可以在 `backend/.env` 設定：

```properties
DB_URL=jdbc:postgresql://localhost:5432/volunteer_record_system
DB_USERNAME=postgres
DB_PASSWORD=你的密碼
```

`.env` 已被 Git 忽略，不要提交資料庫密碼。

### 2. 啟動後端

可從 IntelliJ 執行 `BackendApplication`，或在 `backend/` 執行：

```powershell
.\mvnw.cmd spring-boot:run
```

本機後端網址為 `http://127.0.0.1:8080`。

### 3. 啟動前端

在 `frontend/` 執行：

```powershell
npm.cmd install
npm.cmd start
```

本機前端網址為 `http://127.0.0.1:3000`。如果出現 `EADDRINUSE`，代表已有程式正在使用 3000 連接埠，不需要再啟動第二個前端 server。

## 驗證

前端：

```powershell
cd frontend
npm.cmd run build
```

後端：

```powershell
cd backend
.\mvnw.cmd test
```

## 本機、Push 與上線

- 本機前端呼叫 `http://127.0.0.1:8080`。
- Render 前端呼叫 `https://volunteer-record-system.onrender.com`。
- Push 只代表將 Git commit 推到遠端。
- 如果 Render 對該分支啟用了 Auto-Deploy，push 後 Render 仍可能自動重新部署。
- 本機 PostgreSQL 與 Neon 不會因為 push 或部署而同步；資料庫 migration 必須分別執行。
