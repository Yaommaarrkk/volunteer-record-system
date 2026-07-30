# ARCHITECTURE

## 系統全貌

```text
瀏覽器
  │
  ├─ 本機：http://127.0.0.1:3000
  │        └─ API：http://127.0.0.1:8080
  │
  └─ Render 前端
           └─ Render Spring Boot API
                    └─ Neon PostgreSQL
```

正式環境的前端、後端與資料庫是三個不同服務。

## 前端

位置：`frontend/`

- PureScript 編譯為 JavaScript bundle。
- Halogen 管理元件狀態、Action、Output 與 Slot。
- Routing Duplex 管理 hash route。
- Affjax 呼叫 Spring Boot API。
- `src/Config/Api.js` 依 hostname 選擇本機或 Render API。
- `server.js` 只負責提供 `dist/` 內的靜態 HTML、CSS、JavaScript 與 favicon。

主要分層：

```text
src/Page/       頁面級 Halogen 元件
src/Widget/     可由頁面掛載的功能元件
src/Domain/     前端資料型別與轉換
src/Router/     Route 型別、codec 與頁面切換
src/Config/     API 環境設定
```

## 後端

位置：`backend/`

- Java 21 與 Spring Boot。
- Controller 負責 HTTP、輸入檢查與回應狀態。
- Repository 使用 `JdbcTemplate` 執行 SQL。
- Domain 表示學生、活動、座位、時數與統計資料。
- DTO 定義 API request／response。
- `DatabaseExcelBackupExporter` 使用 Apache POI 產生 Excel。

目前沒有通用 Service 層，也沒有使用 JPA Entity 儲存主要資料。不要只為了形式上的分層而新增 Service 或 ORM。

主要分層：

```text
controller/     REST API
repository/     JDBC 查詢與 transaction
domain/         核心資料型別
dto/request/    請求格式
dto/response/   回應格式
service/        目前只有適合獨立處理的 Excel 匯出
util/           共用 API response 建立器
```

## 資料流

建立多人時數紀錄：

```text
HourRecordForm
  → POST /api/hour-record
  → HourRecordController 驗證輸入
  → HourRecordRepository transaction
  → 每位 volunteer 各 INSERT 一筆 hour_record
  → 前端重新載入歷史紀錄
```

查看每日總時數：

```text
Summary 頁面
  → GET /api/summary/daily-hours
  → SummaryRepository 聚合 hour_record
  → LEFT JOIN daily_activity
  → DailyHourChart 顯示折線與當日活動
```

## 部署

### 前端 Render 服務

1. 安裝 npm dependencies。
2. 執行前端 build。
3. 用 Node `server.js` 提供 `dist/` 靜態檔案。

### 後端 Render 服務

`backend/Dockerfile` 使用 multi-stage build：

1. Java 21 JDK 執行 Maven package。
2. 將 jar 複製到 Java 21 JRE image。
3. 執行 `java -jar app.jar`。

Render 透過 `PORT` 指定服務連接埠，並透過環境變數提供 Neon 資料庫連線。

### Neon

Neon 只負責 PostgreSQL 資料與 SQL 運算，不提供前端頁面或執行 Spring Boot。Render 後端透過 PostgreSQL 連線與 Neon 互動。

## 重要邊界

- 前端 server 不執行 PureScript 原始碼；它提供編譯後的靜態檔案。
- 瀏覽器負責實際執行前端 JavaScript 與渲染畫面。
- 後端負責驗證、SQL 與檔案匯出。
- Push、Render 部署與資料庫 migration 是三個分開的流程。
- Render 重新部署不會替 Neon 執行新的 SQL migration。
