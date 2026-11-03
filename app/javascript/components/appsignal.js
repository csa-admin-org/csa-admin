import Appsignal from "@appsignal/javascript"

// Page URLs can carry a single-use login token or a reusable newsletter token.
// Regexes are created per call so a global lastIndex cannot skip the next match.
export function filterSensitiveUrl(value) {
  if (typeof value !== "string") return value

  return value
    .replace(/\/sessions\/[^/?#]+/g, "/sessions/[FILTERED]")
    .replace(/\/newsletters\/(un)?subscribe\/[^/?#]+/g, "/newsletters/$1subscribe/[FILTERED]")
}

function filterSpanUrl(span) {
  const action = span.getAction()
  if (action) span.setAction(filterSensitiveUrl(action))

  const error = span.getError()
  if (error) {
    const message = filterSensitiveUrl(error.message)
    const backtrace = (error.backtrace || []).map(filterSensitiveUrl)
    const changed =
      message !== error.message || backtrace.some((line, index) => line !== error.backtrace[index])
    if (changed) {
      span.setError({
        name: error.name,
        message,
        stack: backtrace.join("\n")
      })
    }
  }

  const breadcrumbs = span.getBreadcrumbs()
  if (breadcrumbs.length > 0) {
    span.setBreadcrumbs(
      breadcrumbs.map((breadcrumb) => ({
        ...breadcrumb,
        action: filterSensitiveUrl(breadcrumb.action)
      }))
    )
  }

  return span
}

export const appsignal = new Appsignal({
  key: "da2af09a-a494-44ea-aa4c-90fb690ec0fa",
  ignoreErrors: [
    /AbortError: Fetch is aborted/,
    /AbortError: The operation was aborted/,
    /AbortError: The operation was aborted/,
    /Error: Invalid call to runtime.sendMessage(). Tab not found./,
    /Error: Method not found/,
    /Error: Permission denied to access property/,
    /Error: Timeout/,
    /Error: Unable to parse import map JSON Parse error/,
    /Error: Unable to resolve specifier/,
    /ErrorEvent: Event/,
    /SyntaxError: Unexpected end of input/,
    /SyntaxError: Unexpected private name/,
    /SyntaxError: Unexpected token/,
    /TypeError: 404 Not Found/,
    /TypeError: Content-Length header of network response exceeds response Body/,
    /TypeError: Error resolving module specifier/,
    /TypeError: Failed to fetch/,
    /TypeError: Failed to resolve module specifier/,
    /TypeError: Load failed/,
    /TypeError: Module specifier/,
    /TypeError: NetworkError when attempting to fetch resource/,
    /TypeError: Unable to fetch/,
    /TypeError: undefined is not an object/,
    /UnhandledRejection: Non-Error promise rejection captured with value/
  ]
})

appsignal.addDecorator(filterSpanUrl)
