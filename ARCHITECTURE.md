# ARCHITECTURE

## 結構方向

### 前端

- 使用 PureScript + Halogen 建立 Web 前端
- 三個主要頁面：/master-data、/records、/summary
- 使用簡單的列表、表單、勾選框與排序操作流程

### 後端

- 使用 Spring Boot 建立 REST API
- 分層為 Controller / Service / Repository / Entity

### 資料庫

- 使用 Neon 提供的 PostgreSQL
- 主要資料表包含學生、活動模板、時數紀錄

## 基本資料流

1. 使用者在 /master-data 管理學生與活動模板
2. 使用者在 /records 選取學生與活動，批次建立紀錄
3. 系統將資料寫入資料庫
4. 使用者在 /summary 查看所有學生資料，包含年級、總時數或分類時數，並可依條件排序
5. 使用者可再次查詢與檢視紀錄
