export const isPositiveOneDecimal = value => /^(?:\d+)(?:\.\d)?$/.test(value) && Number(value) > 0;

export const focusHoursInputAfterRender = () => {
  window.requestAnimationFrame(() => {
    const input = document.querySelector("[data-hour-record-hours-input]");
    if (input instanceof HTMLInputElement) {
      input.focus();
    }
  });
};

export const focusNoteInputAfterClear = () => {
  window.requestAnimationFrame(() => {
    const input = document.querySelector("[data-hour-record-note-input]");
    if (input instanceof HTMLInputElement) {
      input.focus();
    }
  });
};

export const getTodayIsoDate = () => {
  const today = new Date();
  const year = today.getFullYear();
  const month = String(today.getMonth() + 1).padStart(2, "0");
  const day = String(today.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};

const hourRecordDraftKey = "volunteer-record-system.hour-record-draft";
const hourRecordDraftLifetimeMs = 3 * 60 * 60 * 1000;
const selectedSeatPeriodKey = "volunteer-record-system.selected-seat-period";

export const loadSelectedSeatPeriod = () => {
  try {
    return window.localStorage.getItem(selectedSeatPeriodKey) ?? "";
  } catch {
    return "";
  }
};

export const saveSelectedSeatPeriod = value => () => {
  try {
    window.localStorage.setItem(selectedSeatPeriodKey, value);
  } catch {
    // localStorage 不可用時維持原本選擇行為。
  }
};

export const loadHourRecordDraft = () => {
  try {
    const storedValue = window.localStorage.getItem(hourRecordDraftKey);
    if (storedValue === null) {
      return "";
    }

    const storedDraft = JSON.parse(storedValue);
    if (
      typeof storedDraft.expiresAt !== "number"
      || typeof storedDraft.value !== "string"
      || Date.now() >= storedDraft.expiresAt
    ) {
      window.localStorage.removeItem(hourRecordDraftKey);
      return "";
    }

    return storedDraft.value;
  } catch {
    window.localStorage.removeItem(hourRecordDraftKey);
    return "";
  }
};

export const saveHourRecordDraft = value => () => {
  try {
    window.localStorage.setItem(
      hourRecordDraftKey,
      JSON.stringify({
        expiresAt: Date.now() + hourRecordDraftLifetimeMs,
        value,
      }),
    );
  } catch {
    // localStorage 不可用時維持原本表單行為，不中斷使用者輸入。
  }
};

export const clearHourRecordDraft = () => {
  try {
    window.localStorage.removeItem(hourRecordDraftKey);
  } catch {
    // localStorage 不可用時不需要額外處理。
  }
};
