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

export function normalizedQuantity(value, { step, min, max }) {
  const current = Number(value)
  if (value === "" || !Number.isFinite(current)) return value

  let next = current
  if (step === "1" && !Number.isInteger(current)) next = Math.round(current)
  if (min !== "" && next < Number(min)) return min
  if (max !== "" && next > Number(max)) return max
  if (next === current) return value
  return next
}
