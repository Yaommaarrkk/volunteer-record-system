package com.example.backend.service;

import com.example.backend.dto.response.DatabaseBackupSheet;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.sql.Date;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;

@Service
public class DatabaseExcelBackupExporter {
    public byte[] export(List<DatabaseBackupSheet> backupSheets) {
        try (
                Workbook workbook = new XSSFWorkbook();
                ByteArrayOutputStream output = new ByteArrayOutputStream()
        ) {
            CellStyle headerStyle = createHeaderStyle(workbook);
            CellStyle dateStyle = createDataStyle(workbook, "yyyy-mm-dd");
            CellStyle timestampStyle = createDataStyle(workbook, "yyyy-mm-dd hh:mm:ss");

            for (DatabaseBackupSheet backupSheet : backupSheets) {
                writeSheet(workbook, backupSheet, headerStyle, dateStyle, timestampStyle);
            }

            workbook.write(output);
            return output.toByteArray();
        } catch (IOException error) {
            throw new UncheckedIOException("無法建立資料庫 Excel 備份", error);
        }
    }

    private void writeSheet(
            Workbook workbook,
            DatabaseBackupSheet backupSheet,
            CellStyle headerStyle,
            CellStyle dateStyle,
            CellStyle timestampStyle
    ) {
        Sheet sheet = workbook.createSheet(backupSheet.name());
        Row header = sheet.createRow(0);
        for (int column = 0; column < backupSheet.columns().size(); column++) {
            Cell cell = header.createCell(column);
            cell.setCellValue(backupSheet.columns().get(column));
            cell.setCellStyle(headerStyle);
        }

        for (int rowIndex = 0; rowIndex < backupSheet.rows().size(); rowIndex++) {
            Row row = sheet.createRow(rowIndex + 1);
            List<Object> values = backupSheet.rows().get(rowIndex);
            for (int column = 0; column < values.size(); column++) {
                writeCell(row.createCell(column), values.get(column), dateStyle, timestampStyle);
            }
        }

        sheet.createFreezePane(0, 1);
        sheet.setAutoFilter(new org.apache.poi.ss.util.CellRangeAddress(
                0,
                Math.max(0, backupSheet.rows().size()),
                0,
                Math.max(0, backupSheet.columns().size() - 1)
        ));
        setColumnWidths(sheet, backupSheet.columns());
    }

    private void writeCell(
            Cell cell,
            Object value,
            CellStyle dateStyle,
            CellStyle timestampStyle
    ) {
        if (value == null) {
            cell.setBlank();
        } else if (value instanceof LocalDate localDate) {
            cell.setCellValue(Date.valueOf(localDate));
            cell.setCellStyle(dateStyle);
        } else if (value instanceof Timestamp timestamp) {
            cell.setCellValue(timestamp);
            cell.setCellStyle(timestampStyle);
        } else if (value instanceof java.sql.Date date) {
            cell.setCellValue(date);
            cell.setCellStyle(dateStyle);
        } else if (value instanceof Instant instant) {
            cell.setCellValue(java.util.Date.from(instant));
            cell.setCellStyle(timestampStyle);
        } else if (value instanceof OffsetDateTime offsetDateTime) {
            cell.setCellValue(java.util.Date.from(offsetDateTime.toInstant()));
            cell.setCellStyle(timestampStyle);
        } else if (value instanceof LocalDateTime localDateTime) {
            cell.setCellValue(java.util.Date.from(
                    localDateTime.atZone(ZoneId.systemDefault()).toInstant()
            ));
            cell.setCellStyle(timestampStyle);
        } else if (value instanceof BigDecimal number) {
            cell.setCellValue(number.doubleValue());
        } else if (value instanceof BigInteger number) {
            cell.setCellValue(number.doubleValue());
        } else if (value instanceof Number number) {
            cell.setCellValue(number.doubleValue());
        } else if (value instanceof Boolean bool) {
            cell.setCellValue(bool);
        } else {
            cell.setCellValue(value.toString());
        }
    }

    private CellStyle createHeaderStyle(Workbook workbook) {
        CellStyle style = workbook.createCellStyle();
        style.setFillForegroundColor(IndexedColors.LIGHT_CORNFLOWER_BLUE.getIndex());
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        var font = workbook.createFont();
        font.setBold(true);
        style.setFont(font);
        return style;
    }

    private CellStyle createDataStyle(Workbook workbook, String format) {
        CellStyle style = workbook.createCellStyle();
        style.setDataFormat(workbook.getCreationHelper().createDataFormat().getFormat(format));
        return style;
    }

    private void setColumnWidths(Sheet sheet, List<String> columns) {
        for (int column = 0; column < columns.size(); column++) {
            String name = columns.get(column);
            int width =
                    name.equals("note") ? 40
                    : name.endsWith("_at") ? 22
                    : name.equals("name") ? 24
                    : name.contains("type") || name.equals("period") ? 24
                    : 16;
            sheet.setColumnWidth(column, width * 256);
        }
    }
}
