# API

目前 Controller 實作是 API 的最終依據。本機 base URL 為 `http://127.0.0.1:8080`，正式環境為 `https://volunteer-record-system.onrender.com`。

一般 JSON 回應格式：

```json
{
  "success": true,
  "message": "成功",
  "data": {}
}
```

失敗時 `success` 為 `false`，`data` 為 `null`，HTTP status 會依錯誤類型回傳 `400`、`404`、`409` 或 `500`。

## 學生

| Method | Path | 用途 |
|---|---|---|
| GET | `/api/volunteers` | 取得全部學生與座位 |
| GET | `/api/volunteer/{name}` | 依姓名取得學生 |
| POST | `/api/volunteer` | 新增學生 |
| DELETE | `/api/volunteer/{id}` | 刪除沒有時數紀錄的學生 |
| PATCH | `/api/volunteer/{id}/name` | 修改姓名 |
| PATCH | `/api/volunteer/{id}/age` | 修改年齡／年級資料 |
| PATCH | `/api/volunteer/{id}/seat/{period}` | 新增、修改或清除指定學期座位 |

新增學生範例：

```json
{
  "educationLevel": "ELEMENTARY_SCHOOL",
  "name": "王小明",
  "age": 9,
  "seats": [
    {
      "period": "YEAR_114_SECOND_SEMESTER",
      "seat": {
        "row": 1,
        "col": 2
      }
    }
  ]
}
```

清除座位時，傳入：

```json
{
  "row": null,
  "col": null
}
```

## 活動

| Method | Path | 用途 |
|---|---|---|
| GET | `/api/activities` | 取得活動與類型顏色 |
| POST | `/api/activity` | 新增活動 |
| DELETE | `/api/activity/{id}` | 刪除活動 |
| PATCH | `/api/activity/{id}/name` | 修改活動名 |
| PATCH | `/api/activity/{id}/default-type` | 修改預設類型 |
| PUT | `/api/activities/order` | 更新同一類型內的活動順序 |
| PATCH | `/api/activity-types/{defaultType}/color` | 修改類型標籤色 |

新增活動：

```json
{
  "name": "數學教學",
  "defaultType": "TEACHING"
}
```

排序活動：

```json
{
  "defaultType": "TEACHING",
  "activityIds": [3, 1, 8]
}
```

## 時數紀錄

| Method | Path | 用途 |
|---|---|---|
| POST | `/api/hour-record` | 為多位學生建立各自獨立的時數紀錄 |
| GET | `/api/hour-records?offset=0&limit=20` | 分頁取得登錄歷史 |
| GET | `/api/hour-records/count` | 取得紀錄總筆數 |
| POST | `/api/hour-records/delete` | 批次刪除紀錄 |
| GET | `/api/hour-records/export` | 下載 Excel 資料備份 |
| GET | `/api/record-settings/default-year` | 取得預設年份 |
| PATCH | `/api/record-settings/default-year` | 修改預設年份 |

建立時數紀錄：

```json
{
  "activityId": 1,
  "activityType": "TEACHING",
  "activityDate": "2026-07-15",
  "hours": 1.5,
  "note": "複習分數",
  "volunteerIds": [1001, 1002]
}
```

後端會為每個 `volunteerId` 各新增一筆 `hour_record`。

批次刪除：

```json
{
  "ids": [10, 11, 12]
}
```

## 當日活動

| Method | Path | 用途 |
|---|---|---|
| POST | `/api/daily-activity` | 依日期新增或更新當日活動 |
| GET | `/api/daily-activities?offset=0&limit=20` | 分頁取得當日活動 |
| GET | `/api/daily-activities/count` | 取得總筆數 |
| POST | `/api/daily-activities/delete` | 依日期批次刪除 |

```json
{
  "activityDate": "2026-07-15",
  "description": "戶外教學"
}
```

## 統計

| Method | Path | 用途 |
|---|---|---|
| GET | `/api/summary/volunteer-hours` | 學生教學、互動及其他時數摘要 |
| GET | `/api/summary/volunteer-hours/{volunteerId}` | 單一學生的活動與最近紀錄 |
| GET | `/api/summary/daily-hours` | 每日所有學生總時數與當日活動 |
| GET | `/api/summary/activity-rankings` | 各活動時數最高的學生 |

## Enum

活動類型：

```text
TEACHING
COMPANION_READING
PLAY
DAILY_INTERACTION
PASSIVE
```

學生教育階段：

```text
KINDERGARTEN
ELEMENTARY_SCHOOL
JUNIOR_HIGH_SCHOOL
SENIOR_HIGH_SCHOOL
ADULT
```

目前新增學生流程只實作 `ELEMENTARY_SCHOOL` 與 `JUNIOR_HIGH_SCHOOL` 的編號。

座位時期：

```text
YEAR_114_SECOND_SEMESTER
YEAR_115_SUMMER
```
