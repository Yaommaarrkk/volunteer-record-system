export const subscribeOutsideClick = selector => notify => () => {
  const handlePointerDown = event => {
    const target = event.target;
    const clickedInside = target instanceof Element && target.closest(selector) !== null;

    if (!clickedInside) {
      notify()();
    }
  };

  document.addEventListener("pointerdown", handlePointerDown, true);

  return () => {
    document.removeEventListener("pointerdown", handlePointerDown, true);
  };
};
