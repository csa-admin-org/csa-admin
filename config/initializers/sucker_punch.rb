SuckerPunch.exception_handler = -> (e, klass, args) {
  ExceptionNotifier.notify_exception(e)
  Sentry.capture_exception(e, extra: {
    class_name: klass,
    args: args
  })
}
