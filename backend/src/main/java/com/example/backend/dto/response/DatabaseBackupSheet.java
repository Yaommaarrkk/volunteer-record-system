package com.example.backend.dto.response;

import java.util.List;

public record DatabaseBackupSheet(
        String name,
        List<String> columns,
        List<List<Object>> rows
) {
}
