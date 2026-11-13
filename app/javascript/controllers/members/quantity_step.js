export function nextQuantity(current, delta, { step, max }) {
  const fractional = step !== "1" && !Number.isInteger(current)
  let next = fractional
    ? delta > 0
      ? Math.ceil(current)
      : Math.floor(current)
    : Math.round((current + delta) * 100) / 100
  if (delta > 0 && max !== "" && next > Number(max)) next = Number(max)
  return next
}
