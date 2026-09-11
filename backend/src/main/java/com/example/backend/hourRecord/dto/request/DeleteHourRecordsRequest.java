package com.example.backend.hourRecord.dto.request;

import java.util.List;

public record DeleteHourRecordsRequest(List<Integer> ids) {
}
