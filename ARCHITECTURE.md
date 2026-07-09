# ARCHITECTURE

## 結構方向

### 前端

- 以 Web 頁面為主
- 兩個主要頁面：/master-data、/records
- 使用簡單的列表、表單與勾選框操作流程

### 後端

- 使用 Spring Boot 建立 REST API
- 分層為 Controller / Service / Repository / Entity

### 資料庫

- 使用 Neon 提供的 PostgreSQL
- 主要資料表包含學生、活動模板、時數紀錄

## 基本資料流

1. 使用者在 /master-data 管理學生與活動模板
2. 使用者在 /records 選取學生與活動
3. 系統建立多筆紀錄並寫入資料庫
4. 使用者可再次查詢與檢視紀錄
