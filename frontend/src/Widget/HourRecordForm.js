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
