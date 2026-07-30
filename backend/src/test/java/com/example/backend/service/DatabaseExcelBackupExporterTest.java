package com.example.backend.service;

import com.example.backend.dto.response.DatabaseBackupSheet;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class DatabaseExcelBackupExporterTest {
    @Test
    void exportsMultipleDatabaseTablesWithExcelValueTypes() throws Exception {
        DatabaseBackupSheet volunteers = new DatabaseBackupSheet(
                "volunteer",
                List.of("id", "name"),
                List.of(List.of(1001, "測試學生"))
        );
        DatabaseBackupSheet records = new DatabaseBackupSheet(
                "hour_record",
                List.of("id", "activity_date", "hours", "created_at"),
                List.of(List.of(
                        10,
                        LocalDate.of(2026, 7, 30),
                        new BigDecimal("1.5"),
                        Timestamp.valueOf("2026-07-30 18:30:00")
                ))
        );

        byte[] bytes = new DatabaseExcelBackupExporter().export(List.of(volunteers, records));

        try (XSSFWorkbook workbook = new XSSFWorkbook(new ByteArrayInputStream(bytes))) {
            assertEquals(2, workbook.getNumberOfSheets());
            assertEquals("volunteer", workbook.getSheetAt(0).getSheetName());
            assertEquals("hour_record", workbook.getSheetAt(1).getSheetName());

            var volunteerRow = workbook.getSheet("volunteer").getRow(1);
            assertEquals(CellType.NUMERIC, volunteerRow.getCell(0).getCellType());
            assertEquals("測試學生", volunteerRow.getCell(1).getStringCellValue());

            var recordRow = workbook.getSheet("hour_record").getRow(1);
            assertEquals(CellType.NUMERIC, recordRow.getCell(1).getCellType());
            assertEquals(1.5, recordRow.getCell(2).getNumericCellValue());
            assertEquals(CellType.NUMERIC, recordRow.getCell(3).getCellType());
        }
    }
}
