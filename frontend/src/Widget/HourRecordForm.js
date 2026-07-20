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
