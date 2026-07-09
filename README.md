# 志工小時數紀錄系統

這是一個以 Java + Spring Boot 建立的簡易紀錄系統，目標是讓使用者可以快速批次建立多筆志工時數紀錄。

## 目標

- 管理學生資料
- 管理活動模板
- 透過勾選學生並選擇活動，批次建立時數紀錄
- 提供學生資料總覽頁，顯示每位學生的姓名、年級（由 age 推算）、總時數或指定類別時數，並支援排序
- 以 PureScript + Halogen Web 介面為主，後續可擴充為手機友善版本

## 技術方向

- 後端：Java + Spring Boot
- 資料庫：Neon PostgreSQL
- 前端：PureScript + Halogen，先以簡潔操作流程為主

## 主要頁面

- /master-data：學生與活動管理
- /records：時數紀錄與批次新增
- /summary：學生資料總覽與排序顯示
