package com.example.backend.controller;

import com.example.backend.domain.VolunteerHourSummary;
import com.example.backend.dto.response.Response;
import com.example.backend.repository.SummaryRepository;
import com.example.backend.util.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/summary")
@CrossOrigin(origins = {"http://127.0.0.1:3000", "http://localhost:3000"})
public class SummaryController {
    private final SummaryRepository summaryRepository;

    public SummaryController(SummaryRepository summaryRepository) {
        this.summaryRepository = summaryRepository;
    }

    @GetMapping("/volunteer-hours")
    public ResponseEntity<Response<List<VolunteerHourSummary>>> getVolunteerHourSummaries() {
        return ResponseEntity.ok(ApiResponse.success(summaryRepository.getVolunteerHourSummaries()));
    }
}
