# API

## 主要 API 規劃

### 學生

- GET /api/students
- POST /api/students
- DELETE /api/students/{id}

### 活動模板

- GET /api/activity-templates
- POST /api/activity-templates
- DELETE /api/activity-templates/{id}

### 時數紀錄

- GET /api/records
- POST /api/records/bulk

## 資料格式範例

### 建立學生

```json
{
  "name": "王小明",
  "age": "9"
}
```

### 建立活動模板

```json
{
  "name": "環保清掃",
  "category": "服務",
  "defaultHours": 2.0,
  "note": "校園清掃"
}
```

### 批次建立時數紀錄

```json
{
  "studentIds": [1, 2, 3],
  "activityName": "環保清掃",
  "activityCategoryID": 1,
  "hours": 2.5,
  "note": "本次活動"
}
```
