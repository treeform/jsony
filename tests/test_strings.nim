import jsony

block:
  var s = """ "hello" """
  var v = s.fromJson(string)
  doAssert v == "hello"

block:
  var s = """ "new\nline" """
  var v = s.fromJson(string)
  doAssert v == "new\nline"

block:
  var s = """ "quote\"inside" """
  var v = s.fromJson(string)
  doAssert v == "quote\"inside"

block:
  var s = """ "special: \"\\\/\b\f\n\r\t chars" """
  var v = s.fromJson(string)
  doAssert v == "special: \"\\/\b\f\n\r\t chars"

block:
  var s = """ "unicode: \u0020 \u0F88 \u1F21" """
  var v = s.fromJson(string)
  doAssert v == "unicode: \u0020 \u0F88 \u1F21"

block:
  var s = """ "hello" """ & ""
  var v = s.fromJson(string)
  doAssert v == "hello"
