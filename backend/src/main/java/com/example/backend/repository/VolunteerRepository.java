package com.example.backend.repository;

import java.util.List;
import org.springframework.stereotype.Repository;
import com.example.backend.domain.Volunteer;

@Repository
public class VolunteerRepository {

    private final List<Volunteer> test_volunteers = List.of(
            new Volunteer(1001, "卓辰妍", 8, new Volunteer.Seat(1, 1)),
            new Volunteer(1002, "潘勇仁", 10, new Volunteer.Seat(1, 2)),
            new Volunteer(2001, "潘艾琳", 13, null)
    );

    List<Volunteer> volunteer_ptr = test_volunteers;

    public List<Volunteer> getAll() {
        return volunteer_ptr;
    }

    public Volunteer findByName(String name) {
        return volunteer_ptr.stream()
                .filter(v -> v.getName().equals(name))
                .findFirst()
                .orElse(null);
    }
}