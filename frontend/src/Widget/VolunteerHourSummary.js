export const copySummaryTableImpl = (html) => (plainText) => (onComplete) => () => {
  let completed = false;

  const finish = (success) => {
    if (completed) {
      return;
    }

    completed = true;
    onComplete(success)();
  };

  const copyPlainText = () => {
    if (!navigator.clipboard?.writeText) {
      finish(false);
      return;
    }

    navigator.clipboard.writeText(plainText).then(
      () => finish(true),
      () => finish(false)
    );
  };

  if (navigator.clipboard?.write && globalThis.ClipboardItem) {
    const item = new ClipboardItem({
      "text/html": new Blob([html], { type: "text/html" }),
      "text/plain": new Blob([plainText], { type: "text/plain" })
    });

    navigator.clipboard.write([item]).then(
      () => finish(true),
      copyPlainText
    );
    return;
  }

  copyPlainText();
};
