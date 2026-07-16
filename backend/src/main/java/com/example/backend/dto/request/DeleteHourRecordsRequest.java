package com.example.backend.dto.request;

import java.util.List;

public record DeleteHourRecordsRequest(List<Integer> ids) {
}
