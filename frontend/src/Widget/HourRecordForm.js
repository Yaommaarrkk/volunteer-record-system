export const isPositiveOneDecimal = value => /^(?:\d+)(?:\.\d)?$/.test(value) && Number(value) > 0;
