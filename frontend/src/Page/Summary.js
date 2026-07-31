const selectedSummaryViewKey = "volunteer-record-system.selected-summary-view";

export const loadSelectedSummaryView = () => {
  try {
    return window.localStorage.getItem(selectedSummaryViewKey) ?? "";
  } catch {
    return "";
  }
};

export const saveSelectedSummaryView = value => () => {
  try {
    window.localStorage.setItem(selectedSummaryViewKey, value);
  } catch {
    // localStorage 不可用時維持原本選擇行為。
  }
};
