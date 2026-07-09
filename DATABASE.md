# DATABASE

## 建議資料表

### students

- id
- name
- age
- created_at

### activity_templates

- id
- name
- category
- default_hours
- note
- created_at

### volunteer_records

- id
- student_id
- activity_name
- activity_categoryID
- hours
- record_date
- note
- created_at

## 關係

- 一個學生可以有多筆時數紀錄

## 資料總覽頁需求

- 不需要額外儲存年級欄位
- 前端可由學生的 age 轉成顯示用的年級標籤
- 資料總覽頁可透過查詢計算每位學生的總時數，或依活動分類計算指定類別時數
- 這個頁面可由學生與時數紀錄表做聚合查詢，並支援排序
