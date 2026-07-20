package com.example.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.CrossOrigin;

import com.example.backend.domain.Volunteer;
import com.example.backend.domain.SeatPeriod;
import com.example.backend.dto.request.CreateVolunteerRequest;
import com.example.backend.dto.request.UpdateVolunteerAgeRequest;
import com.example.backend.dto.request.UpdateVolunteerNameRequest;
import com.example.backend.dto.request.UpdateVolunteerSeatRequest;
import com.example.backend.dto.response.Response;
import com.example.backend.repository.VolunteerRepository;
import com.example.backend.util.ApiResponse;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = {"http://127.0.0.1:3000", "http://localhost:3000"})
public class UserController {

    private final VolunteerRepository volunteerRepository;

    public UserController(VolunteerRepository volunteerRepository) {
        this.volunteerRepository = volunteerRepository;
    }

    @GetMapping("/volunteer/{name}")
    public ResponseEntity<Response<Volunteer>> getVolunteer(@PathVariable String name) {
        Volunteer volunteer = volunteerRepository.findByName(name);
        if(volunteer != null) {
            return ResponseEntity.ok(ApiResponse.success(volunteer));
        }

        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.fail("名稱: <" + name + "> 不存在"));

    }

    @GetMapping("/volunteers")
    public ResponseEntity<Response<List<Volunteer>>> getVolunteers() {
        List<Volunteer> volunteers = volunteerRepository.getAll();
        return ResponseEntity.ok(
                ApiResponse.success(volunteers)
        );
    }
    
    @PostMapping("/volunteer")
    public ResponseEntity<Response<Void>> createVolunteer(@RequestBody CreateVolunteerRequest request) {
        try {
            Integer id = volunteerRepository.nextId(request.educationLevel());
            Volunteer volunteer = new Volunteer(
                    id,
                    request.name(),
                    request.age()
            );

            if (request.seats() != null) {
                for (CreateVolunteerRequest.SeatAssignmentRequest assignment : request.seats()) {
                    if (assignment != null && assignment.seat() != null) {
                        volunteer.addSeat(
                                new Volunteer.SeatAssignment(
                                        assignment.period(),
                                        new Volunteer.Seat(
                                                assignment.seat().row(),
                                                assignment.seat().col()
                                        )
                                )
                        );
                    }
                }
            }

            int insertedRows = volunteerRepository.insert(volunteer);
            if (insertedRows != 1) {
                return ResponseEntity
                        .status(HttpStatus.INTERNAL_SERVER_ERROR)
                        .body(ApiResponse.fail("新增學生失敗"));
            }

            return ResponseEntity
                    .status(HttpStatus.CREATED)
                    .body(ApiResponse.success("新增學生成功", null));
        } catch (IllegalArgumentException error) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail(error.getMessage()));
        }
    }

    @DeleteMapping("/volunteer/{id}")
    public ResponseEntity<Response<Void>> deleteVolunteer(@PathVariable Integer id) {
        int deletedRows;
        try {
            deletedRows = volunteerRepository.deleteById(id);
        } catch (DataIntegrityViolationException error) {
            return ResponseEntity
                    .status(HttpStatus.CONFLICT)
                    .body(ApiResponse.fail("這位學生已有時數紀錄，不能直接刪除"));
        }

        if (deletedRows == 0) {
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.fail("編號: <" + id + "> 不存在"));
        }

        return ResponseEntity.ok(
                ApiResponse.success("刪除學生成功", null)
        );
    }

    @PatchMapping("/volunteer/{id}/name")
    public ResponseEntity<Response<Void>> updateVolunteerName(
            @PathVariable Integer id,
            @RequestBody UpdateVolunteerNameRequest request
    ) {
        if (request.name() == null || request.name().trim().isEmpty()) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("姓名不能為空"));
        }

        int updatedRows = volunteerRepository.updateName(id, request.name().trim());
        if (updatedRows == 0) {
            return volunteerNotFound(id);
        }

        return ResponseEntity.ok(ApiResponse.success("修改姓名成功", null));
    }

    @PatchMapping("/volunteer/{id}/age")
    public ResponseEntity<Response<Void>> updateVolunteerAge(
            @PathVariable Integer id,
            @RequestBody UpdateVolunteerAgeRequest request
    ) {
        if (request.age() == null || request.age() < 5 || request.age() > 15) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("年級資料超出可選範圍"));
        }

        int updatedRows = volunteerRepository.updateAge(id, request.age());
        if (updatedRows == 0) {
            return volunteerNotFound(id);
        }

        return ResponseEntity.ok(ApiResponse.success("修改年級成功", null));
    }

    @PatchMapping("/volunteer/{id}/seat/{period}")
    public ResponseEntity<Response<Void>> updateVolunteerSeat(
            @PathVariable Integer id,
            @PathVariable SeatPeriod period,
            @RequestBody UpdateVolunteerSeatRequest request
    ) {
        if (!volunteerRepository.existsById(id)) {
            return volunteerNotFound(id);
        }

        boolean isClearingSeat = request.row() == null && request.col() == null;
        boolean isValidSeat =
                request.row() != null && request.row() >= 1 && request.row() <= 5
                        && request.col() != null && request.col() >= 1 && request.col() <= 4;

        if (!isClearingSeat && !isValidSeat) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.fail("座位資料超出可選範圍"));
        }

        volunteerRepository.updateSeat(id, period, request.row(), request.col());
        return ResponseEntity.ok(ApiResponse.success("修改座位成功", null));
    }

    private ResponseEntity<Response<Void>> volunteerNotFound(Integer id) {
        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.fail("編號: <" + id + "> 不存在"));
    }

}
