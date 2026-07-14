package com.example.backend.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.CrossOrigin;

import com.example.backend.domain.Volunteer;
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
    public ResponseEntity<Response<Volunteer>> volunteer(@PathVariable String name) {
        Volunteer volunteer = volunteerRepository.findByName(name);
        if(volunteer != null) {
            return ResponseEntity.ok(ApiResponse.success(volunteer));
        }

        return ResponseEntity
                .status(HttpStatus.NOT_FOUND)
                .body(ApiResponse.fail("名稱: <" + name + "> 不存在"));

    }

    @GetMapping("/volunteers")
    public ResponseEntity<Response<List<Volunteer>>> volunteer() {
        List<Volunteer> volunteers = volunteerRepository.getAll();
        return ResponseEntity.ok(
                ApiResponse.success(volunteers)
        );
    }

}
