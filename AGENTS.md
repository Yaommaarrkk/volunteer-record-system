# 志工小時數紀錄系統開發規則

## 專案定位

- 這是使用者用來學習 Java、Spring Boot、PostgreSQL、PureScript 與 Halogen 的個人專案。
- 優先維持程式容易理解、容易手動練習，不為了「更專業」而擅自增加抽象層。
- 前端位於 `frontend/`，後端位於 `backend/`，資料庫使用 PostgreSQL。
- 本機 PostgreSQL 與 Neon 是兩套獨立資料庫，不會自動同步。

## 溝通與修改範圍

- 使用繁體中文溝通。
- 資訊不足且不同選擇會明顯影響結果時，先向使用者確認。
- 嚴格遵守使用者指定的修改範圍，不順便重構、重新命名或處理相鄰問題。
- 不刪除、改寫或移動使用者原本的註解，除非使用者明確要求。
- 保留工作目錄中與目前任務無關的既有修改。
- 使用者要求教學或引導時，解釋觀念並保留適合的部分讓使用者親手完成。
- 使用者只要求診斷或說明時，不直接實作修正。

## 前端

- 使用 PureScript、Halogen 與現有的 Widget／Slot 架構。
- 延續現有元件、Action、Output、父子互動與 CSS 命名風格。
- 不因為能抽象就主動新增共用元件；只有確實重複且能降低理解成本時才抽取。
- 修改前端後，在 `frontend/` 執行：

```powershell
npm.cmd run build
```

## 後端

- 使用現有的 Controller、Repository、Domain 與 DTO 結構。
- 不主動加入新的框架、ORM、Service 層或抽象，除非使用者要求。
- SQL 參數使用 JDBC 的參數綁定，不以字串拼接使用者輸入。
- 依修改風險在 `backend/` 執行：

```powershell
.\mvnw.cmd test
```

- 若只需快速確認編譯，可執行：

```powershell
.\mvnw.cmd -DskipTests compile
```

## 資料庫

- 資料表或欄位異動必須在 `backend/sql/` 新增可追蹤的 migration SQL。
- 不修改已經執行過的舊 migration 來假裝新增異動不存在。
- 不在未經使用者明確要求時，直接對本機或 Neon 執行會改變資料的 SQL。
- 完成 migration 後，明確提醒使用者需要在本機 PostgreSQL 與 Neon 分別執行。
- 不把資料庫密碼、連線字串或 `.env` 提交到 Git。

## Git、Push 與部署

- 未經明確要求，不建立 commit、不 push、不合併分支、不部署。
- 執行 Git 寫入操作前，先檢查目前分支、`git status` 與待提交差異。
- 使用者說「push」時，只提交目前任務範圍的修改並推送指定或目前分支。
- 未指定 commit 訊息時，依實際修改產生簡短、準確的英文 Conventional Commit 訊息。
- Push 與部署是不同操作；除非使用者明確要求，不主動操作 Render 部署。
- 若 Render 已開啟自動部署，推送到其監看的分支仍可能由 Render 自動上線，應在相關情況提醒使用者。
- 不使用破壞性的 Git 指令覆蓋或移除使用者修改。

## 完成與回報

- 驗證程度需符合修改風險，不為小型文字調整執行無關的完整測試。
- 回報實際執行的編譯或測試結果，不宣稱未執行的檢查已通過。
- 清楚說明是否已 commit、push 或部署。
