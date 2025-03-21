import Appsignal from "@appsignal/javascript"

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
