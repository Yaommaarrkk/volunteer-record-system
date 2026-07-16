package com.example.backend.controller;

import com.example.backend.domain.Activity;
import com.example.backend.domain.ActivityType;
import com.example.backend.dto.request.CreateActivityRequest;
import com.example.backend.dto.request.ReorderActivitiesRequest;
import com.example.backend.dto.request.UpdateActivityColorRequest;
import com.example.backend.dto.request.UpdateActivityNameRequest;
import com.example.backend.dto.request.UpdateActivityNoteRequest;
import com.example.backend.dto.request.UpdateActivityTypeRequest;
import com.example.backend.dto.response.Response;
import com.example.backend.repository.ActivityRepository;
import com.example.backend.util.ApiResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = {"http://127.0.0.1:3000", "http://localhost:3000"})
public class ActivityController {
    private final ActivityRepository activityRepository;

    public ActivityController(ActivityRepository activityRepository) {
        this.activityRepository = activityRepository;
    }

    @GetMapping("/activities")
    public ResponseEntity<Response<List<Activity>>> getActivities() {
        return ResponseEntity.ok(ApiResponse.success(activityRepository.getAll()));
    }

    @PostMapping("/activity")
    public ResponseEntity<Response<Void>> createActivity(@RequestBody CreateActivityRequest request) {
        if (request.name() == null || request.name().trim().isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("活動名不能為空"));
        }

        if (request.defaultType() == null) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("預設類型不能為空"));
        }

        String defaultNote = request.defaultNote() == null ? "" : request.defaultNote().trim();
        int insertedRows = activityRepository.insert(
                request.name().trim(),
                request.defaultType(),
                defaultNote
        );

        if (insertedRows != 1) {
            return ResponseEntity
                    .status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(ApiResponse.fail("新增活動失敗"));
        }

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(ApiResponse.success("新增活動成功", null));
    }

    @DeleteMapping("/activity/{id}")
    public ResponseEntity<Response<Void>> deleteActivity(@PathVariable Integer id) {
        if (activityRepository.deleteById(id) == 0) {
            return activityNotFound(id);
        }

        return ResponseEntity.ok(ApiResponse.success("刪除活動成功", null));
    }

    @PatchMapping("/activity/{id}/name")
    public ResponseEntity<Response<Void>> updateActivityName(
            @PathVariable Integer id,
            @RequestBody UpdateActivityNameRequest request
    ) {
        if (request.name() == null || request.name().trim().isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("活動名不能為空"));
        }

        if (activityRepository.updateName(id, request.name().trim()) == 0) {
            return activityNotFound(id);
        }

        return ResponseEntity.ok(ApiResponse.success("修改活動名成功", null));
    }

    @PatchMapping("/activity/{id}/default-type")
    public ResponseEntity<Response<Void>> updateActivityType(
            @PathVariable Integer id,
            @RequestBody UpdateActivityTypeRequest request
    ) {
        if (request.defaultType() == null) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("預設類型不能為空"));
        }

        if (activityRepository.updateDefaultType(id, request.defaultType()) == 0) {
            return activityNotFound(id);
        }

        return ResponseEntity.ok(ApiResponse.success("修改預設類型成功", null));
    }

    @PatchMapping("/activity/{id}/default-note")
    public ResponseEntity<Response<Void>> updateActivityNote(
            @PathVariable Integer id,
            @RequestBody UpdateActivityNoteRequest request
    ) {
        String defaultNote = request.defaultNote() == null ? "" : request.defaultNote().trim();
        if (activityRepository.updateDefaultNote(id, defaultNote) == 0) {
            return activityNotFound(id);
        }

        return ResponseEntity.ok(ApiResponse.success("修改預設備註成功", null));
    }

    @PutMapping("/activities/order")
    public ResponseEntity<Response<Void>> reorderActivities(
            @RequestBody ReorderActivitiesRequest request
    ) {
        if (request.defaultType() == null || request.activityIds() == null) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("活動排序資料不完整"));
        }

        if (!activityRepository.reorder(request.defaultType(), request.activityIds())) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("活動排序資料與目前類型不一致"));
        }

        return ResponseEntity.ok(ApiResponse.success("活動排序已更新", null));
    }

    @PatchMapping("/activity-types/{defaultType}/color")
    public ResponseEntity<Response<Void>> updateActivityTypeColor(
            @PathVariable ActivityType defaultType,
            @RequestBody UpdateActivityColorRequest request
    ) {
        if (request.tagColor() == null
                || !request.tagColor().matches("^#[0-9A-Fa-f]{6}$")) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("活動類型顏色格式錯誤"));
        }

        if (activityRepository.updateTypeColor(defaultType, request.tagColor().toUpperCase()) == 0) {
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.fail("活動類型不存在"));
        }

        return ResponseEntity.ok(ApiResponse.success("活動類型顏色已更新", null));
    }

    private ResponseEntity<Response<Void>> activityNotFound(Integer id) {
        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.fail("活動編號: <" + id + "> 不存在"));
    }
}
