import jsony

block:
  var s = """ "hello" """
  var v = fromJson[string](s)
  doAssert v == "hello"

block:
  var s = """ "new\nline" """
  var v = fromJson[string](s)
  doAssert v == "new\nline"

block:
  var s = """ "quote\"inside" """
  var v = fromJson[string](s)
  doAssert v == "quote\"inside"

block:
  var s = """ "special: \"\\\/\b\f\n\r\t chars" """
  var v = fromJson[string](s)
  doAssert v == "special: \"\\/\b\f\n\r\t chars"

block:
  var s = """ "unicode: \u0020 \u0F88 \u1F21" """
  var v = fromJson[string](s)
  doAssert v == "unicode: \u0020 \u0F88 \u1F21"
