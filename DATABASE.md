# DATABASE

## 建議資料表

### students

- id
- name
- email
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
