# DATABASE

## 環境

專案有兩套彼此獨立的 PostgreSQL：

- 本機：`volunteer_record_system`
- 正式環境：Neon 的 `neondb`

本機資料、Neon 資料與 schema 都不會自動同步。SQL migration 必須在兩邊分別執行，執行前先確認 Query Tool 目前連到哪個 database。

## 目前主要資料表

### `volunteer`

學生基本資料。

- `id`：學生編號
- `name`
- `age`：前端轉換成年級顯示
- `created_at`
- `updated_at`

國小與國中編號分別由 PostgreSQL sequence 產生：

- `elementary_volunteer_id_seq`
- `junior_high_volunteer_id_seq`

### `volunteer_seat`

一位學生在不同時期的座位。

- `volunteer_id`：FK → `volunteer.id`
- `period`
- `seat_row`：1～5
- `seat_col`：1～4
- PK：`(volunteer_id, period)`

刪除學生時，座位會透過 `ON DELETE CASCADE` 一起刪除。

### `activity`

可選活動。

- `id`
- `name`
- `default_type`
- `sort_order`：同一類型內的順序
- `created_at`
- `updated_at`

### `activity_type_color`

活動類型的前端標籤色。

- `default_type`
- `tag_color`：`#RRGGBB`

### `hour_record`

每位學生各自一筆的時數紀錄。

- `id`
- `activity_id`：FK → `activity.id`
- `volunteer_id`：FK → `volunteer.id`
- `activity_type`
- `activity_date`
- `hours`：正數，最多一位小數
- `note`
- `created_at`
- `updated_at`

一個表單若選擇五位學生，後端會新增五筆 `hour_record`。

### `record_setting`

時數登錄頁的共用設定，目前只有一列：

- `setting_id = 1`
- `default_year`

### `daily_activity`

一個日期對應一段當日主要活動說明。

- `activity_date`：PK
- `description`
- `created_at`
- `updated_at`

## 關係

```text
volunteer 1 ── N volunteer_seat
volunteer 1 ── N hour_record
activity  1 ── N hour_record
```

刪除已有 `hour_record` 的學生會被 FK 阻止。刪除活動是否成功也受既有時數紀錄關係影響。

## SQL migration

SQL 放在 `backend/sql/`。目前這些檔案記錄專案演進過程中的手動 migration，尚未導入 Flyway 或 Liquibase。

注意：

- 它們不是一套可以對空資料庫依檔名順序全部執行的完整 baseline。
- 部分較新的 `CREATE` 檔已包含後來新增的欄位，而舊 `ALTER` 檔是留給較早期資料庫升級使用。
- 執行前先查看目標資料庫目前有哪些 table、column、constraint、sequence 與 trigger。
- SQL 發生錯誤時，確認 transaction 是否已 rollback，再處理下一步。
- 不要在本機成功後就假設 Neon 也完成；兩邊要分別檢查。

## 備份

網頁的 Excel 備份會匯出主要資料表，方便閱讀與保存，但它不是可直接還原 PostgreSQL schema、constraint、sequence 與 trigger 的完整備份。

需要完整搬移資料庫時，使用 PostgreSQL 的 `pg_dump`／`pg_restore`。`*.backup` 已被 `.gitignore` 排除，不應提交到 Git。

## 連線設定

`backend/src/main/resources/application.yaml` 讀取：

```text
DB_URL
DB_USERNAME
DB_PASSWORD
PORT
```

本機可放在 `backend/.env`。Render 則應在服務的 Environment Variables 設定，不要將密碼寫入版本控制。
