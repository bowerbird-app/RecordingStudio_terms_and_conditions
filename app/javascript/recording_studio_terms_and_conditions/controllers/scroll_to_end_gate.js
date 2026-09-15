export function shouldLockAgree(canObserve, endVisible) {
  return canObserve === true && endVisible !== true
}

export function elementIsInViewport(element, viewportHeight) {
  if (!element || typeof element.getBoundingClientRect !== "function") return false

  const rect = element.getBoundingClientRect()
  return rect.bottom > 0 && rect.top < viewportHeight
}
