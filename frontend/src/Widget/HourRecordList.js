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
  const sentinel = document.querySelector("[data-hour-record-load-more]");
  if (!(sentinel instanceof HTMLElement)) {
    return false;
  }

  return sentinel.getBoundingClientRect().top <= window.innerHeight + 160;
};
