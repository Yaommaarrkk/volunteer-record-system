package com.example.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.CrossOrigin;

import com.example.backend.domain.Volunteer;
import com.example.backend.dto.request.CreateVolunteerRequest;
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
            Volunteer.Seat seat = request.seat() == null
                    ? null
                    : new Volunteer.Seat(
                            request.seat().row(),
                            request.seat().col()
                    );

            Volunteer volunteer = new Volunteer(
                    id,
                    request.name(),
                    request.age(),
                    seat
            );

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
        int deletedRows = volunteerRepository.deleteById(id);
        if (deletedRows == 0) {
            return ResponseEntity
                    .status(HttpStatus.NOT_FOUND)
                    .body(ApiResponse.fail("編號: <" + id + "> 不存在"));
        }

        return ResponseEntity.ok(
                ApiResponse.success("刪除學生成功", null)
        );
    }

}
