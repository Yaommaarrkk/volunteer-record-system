package com.example.backend.controller;

import com.example.backend.domain.DailyActivity;
import com.example.backend.dto.request.DeleteDailyActivitiesRequest;
import com.example.backend.dto.request.SaveDailyActivityRequest;
import com.example.backend.dto.response.Response;
import com.example.backend.repository.DailyActivityRepository;
import com.example.backend.util.ApiResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = {
        "http://127.0.0.1:3000",
        "http://localhost:3000",
        "https://volunteer-record-system-frontend.onrender.com"
})
public class DailyActivityController {
    private final DailyActivityRepository dailyActivityRepository;

    public DailyActivityController(DailyActivityRepository dailyActivityRepository) {
        this.dailyActivityRepository = dailyActivityRepository;
    }

    @GetMapping("/daily-activities")
    public ResponseEntity<Response<List<DailyActivity>>> getDailyActivities(
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "20") int limit
    ) {
        if (offset < 0 || limit < 1 || limit > 100) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("offset 必須大於等於 0，limit 必須介於 1 到 100"));
        }

        return ResponseEntity.ok(
                ApiResponse.success(dailyActivityRepository.getPage(offset, limit))
        );
    }

    @GetMapping("/daily-activities/count")
    public ResponseEntity<Response<Long>> getDailyActivityCount() {
        return ResponseEntity.ok(ApiResponse.success(dailyActivityRepository.getCount()));
    }

    @PostMapping("/daily-activity")
    public ResponseEntity<Response<Void>> saveDailyActivity(
            @RequestBody SaveDailyActivityRequest request
    ) {
        if (request.activityDate() == null) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("日期不能為空"));
        }

        if (request.description() == null || request.description().trim().isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("當日主要活動不能為空"));
        }

        String description = request.description().trim();
        if (description.length() > 120) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("當日主要活動不能超過 120 個字"));
        }

        if (dailyActivityRepository.save(request.activityDate(), description) != 1) {
            return ResponseEntity
                    .status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.fail("儲存當日活動失敗"));
        }

        return ResponseEntity.ok(ApiResponse.success("當日活動已儲存", null));
    }

    @PostMapping("/daily-activities/delete")
    public ResponseEntity<Response<Void>> deleteDailyActivities(
            @RequestBody DeleteDailyActivitiesRequest request
    ) {
        if (request.activityDates() == null || request.activityDates().isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("請選擇要刪除的當日活動"));
        }

        List<java.time.LocalDate> activityDates =
                request.activityDates().stream().distinct().toList();
        int deletedRows = dailyActivityRepository.deleteByDates(activityDates);
        if (deletedRows < 0) {
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.fail("部分當日活動已不存在，請重新載入"));
        }

        return ResponseEntity.ok(
                ApiResponse.success("已刪除 " + deletedRows + " 筆當日活動", null)
        );
    }
}
