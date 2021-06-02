import jsony

doAssertRaises(JsonError):
  discard "{invalid".fromJson()

doAssertRaises(JsonError):
  discard "{a:}".fromJson()

doAssertRaises(JsonError):
  discard "1.23.23".fromJson()
