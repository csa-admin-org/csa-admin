export const prop = (elementOrSelector, attrName, enabled) => {
  const els = getElements(elementOrSelector)
  for (const el of els) {
    enabled ? el.setAttribute(attrName, attrName) : el.removeAttribute(attrName)
  }
}

export const checked = (elementOrSelector, value) => {
  const els = getElements(elementOrSelector)
  for (const el of els) {
    el.checked = value
  }
}

export const removeValues = (elementOrSelector) => {
  const els = getElements(elementOrSelector)
  for (const el of els) {
    el.value = null
  }
}

export const resetValues = (elementOrSelector, value) => {
  const els = getElements(elementOrSelector)
  for (const el of els) {
    if (el.value == "") el.value = value
  }
}

export const addClass = (elementOrSelector, className) => {
  const els = getElements(elementOrSelector)
  for (const el of els) {
    el.classList.add(className)
  }
}

export const removeClass = (elementOrSelector, className) => {
  const els = getElements(elementOrSelector)
  for (const el of els) {
    el.classList.remove(className)
  }
}

export const show = (elementOrSelector) => {
  const els = getElements(elementOrSelector)
  for (const el of els) {
    el.style.display = "block"
  }
}

export const hide = (elementOrSelector) => {
  const els = getElements(elementOrSelector)
  for (const el of els) {
    el.style.display = "none"
  }
}

const getElements = (elementOrSelector) => {
  if (typeof elementOrSelector === "string") {
    return document.querySelectorAll(elementOrSelector)
  } else if (elementOrSelector instanceof Array) {
    return elementOrSelector
  } else {
    return [elementOrSelector]
  }
}
