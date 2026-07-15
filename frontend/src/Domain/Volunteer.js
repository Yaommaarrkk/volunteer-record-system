const pad = value => String(value).padStart(2, "0");

export const formatUpdatedAt = value => {
  const updatedAt = new Date(value);

  if (Number.isNaN(updatedAt.getTime())) {
    return { date: "-", time: "-" };
  }

  return {
    date: `${updatedAt.getFullYear()}-${pad(updatedAt.getMonth() + 1)}-${pad(updatedAt.getDate())}`,
    time: `${pad(updatedAt.getHours())}:${pad(updatedAt.getMinutes())}:${pad(updatedAt.getSeconds())}`
  };
};
