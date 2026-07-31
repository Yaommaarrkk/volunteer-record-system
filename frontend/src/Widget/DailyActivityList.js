export const subscribeWindowScroll = notify => () => {
  let scheduled = false;

  const handleViewportChange = () => {
    if (scheduled) {
      return;
    }

    scheduled = true;
    window.requestAnimationFrame(() => {
      scheduled = false;
      notify()();
    });
  };

  window.addEventListener("scroll", handleViewportChange, { passive: true });
  window.addEventListener("resize", handleViewportChange);

  return () => {
    window.removeEventListener("scroll", handleViewportChange);
    window.removeEventListener("resize", handleViewportChange);
  };
};

export const isLoadMoreSentinelVisible = () => {
  const sentinel = document.querySelector("[data-daily-activity-load-more]");
  if (!(sentinel instanceof HTMLElement)) {
    return false;
  }

  return sentinel.getBoundingClientRect().top <= window.innerHeight + 160;
};

export const formatActivityDate = (value) => {
  const [yearText, monthText, dayText] = value.split("-");
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);

  if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) {
    return value.replaceAll("-", "/");
  }

  const weekdays = ["日", "一", "二", "三", "四", "五", "六"];
  const weekday = weekdays[new Date(year, month - 1, day).getDay()];
  return `${yearText}/${monthText}/${dayText}(${weekday})`;
};
