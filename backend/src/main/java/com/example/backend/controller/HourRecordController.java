package com.example.backend.controller;

import com.example.backend.dto.request.CreateHourRecordRequest;
import com.example.backend.dto.request.DeleteHourRecordsRequest;
import com.example.backend.dto.request.UpdateDefaultRecordYearRequest;
import com.example.backend.dto.response.Response;
import com.example.backend.domain.HourRecord;
import com.example.backend.repository.HourRecordRepository;
import com.example.backend.repository.RecordSettingRepository;
import com.example.backend.util.ApiResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = {"http://127.0.0.1:3000", "http://localhost:3000"})
public class HourRecordController {
    private final HourRecordRepository hourRecordRepository;
    private final RecordSettingRepository recordSettingRepository;

    public HourRecordController(
            HourRecordRepository hourRecordRepository,
            RecordSettingRepository recordSettingRepository
    ) {
        this.hourRecordRepository = hourRecordRepository;
        this.recordSettingRepository = recordSettingRepository;
    }

    @GetMapping("/record-settings/default-year")
    public ResponseEntity<Response<Integer>> getDefaultYear() {
        return ResponseEntity.ok(ApiResponse.success(recordSettingRepository.getDefaultYear()));
    }

    @PatchMapping("/record-settings/default-year")
    public ResponseEntity<Response<Void>> updateDefaultYear(
            @RequestBody UpdateDefaultRecordYearRequest request
    ) {
        if (request.year() == null || request.year() < 2000 || request.year() > 2100) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("年份必須介於 2000 到 2100"));
        }

        recordSettingRepository.updateDefaultYear(request.year());
        return ResponseEntity.ok(ApiResponse.success("預設年份已更新", null));
    }

    @PostMapping("/hour-record")
    public ResponseEntity<Response<Void>> createHourRecord(
            @RequestBody CreateHourRecordRequest request
    ) {
        if (request.activityId() == null || !hourRecordRepository.activityExists(request.activityId())) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("活動不存在"));
        }

        if (request.activityType() == null || request.activityDate() == null) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("活動類型與日期不能為空"));
        }

        if (request.hours() == null
                || request.hours().signum() <= 0
                || request.hours().stripTrailingZeros().scale() > 1) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("時數必須是正數，且最多一位小數"));
        }

        if (request.volunteerIds() == null || request.volunteerIds().isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("至少選擇一位參與學生"));
        }

        List<Integer> volunteerIds = request.volunteerIds().stream().distinct().toList();
        if (!hourRecordRepository.volunteersExist(volunteerIds)) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("參與學生資料不存在"));
        }

        hourRecordRepository.insert(request, volunteerIds);
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success("已新增 " + volunteerIds.size() + " 筆學生時數紀錄", null));
    }

    @GetMapping("/hour-records")
    public ResponseEntity<Response<List<HourRecord>>> getHourRecords() {
        return ResponseEntity.ok(ApiResponse.success(hourRecordRepository.getAll()));
    }

    @PostMapping("/hour-records/delete")
    public ResponseEntity<Response<Void>> deleteHourRecords(
            @RequestBody DeleteHourRecordsRequest request
    ) {
        if (request.ids() == null || request.ids().isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("請先選擇要刪除的時數紀錄"));
        }

        List<Integer> ids = request.ids().stream().distinct().toList();
        int deletedRows = hourRecordRepository.deleteByIds(ids);
        if (deletedRows < 0) {
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.fail("部分時數紀錄不存在，沒有刪除任何資料"));
        }

        return ResponseEntity.ok(
                ApiResponse.success("已刪除 " + deletedRows + " 筆時數紀錄", null)
        );
    }
}
