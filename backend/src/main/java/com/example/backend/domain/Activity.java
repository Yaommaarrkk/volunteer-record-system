package com.example.backend.domain;

import java.time.Instant;

public class Activity {
    private final Integer id;
    private final String name;
    private final ActivityType defaultType;
    private final String defaultNote;
    private final Integer sortOrder;
    private final String tagColor;
    private final Instant updatedAt;

    public Activity(
            Integer id,
            String name,
            ActivityType defaultType,
            String defaultNote,
            Integer sortOrder,
            String tagColor,
            Instant updatedAt
    ) {
        this.id = id;
        this.name = name;
        this.defaultType = defaultType;
        this.defaultNote = defaultNote;
        this.sortOrder = sortOrder;
        this.tagColor = tagColor;
        this.updatedAt = updatedAt;
    }

    public Integer getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public ActivityType getDefaultType() {
        return defaultType;
    }

    public String getDefaultNote() {
        return defaultNote;
    }

    public Integer getSortOrder() {
        return sortOrder;
    }

    public String getTagColor() {
        return tagColor;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
