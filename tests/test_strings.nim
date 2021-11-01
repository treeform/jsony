import jsony, json

block:
  var s = """ "hello" """
  var v = s.fromJson(string)
  doAssert v == "hello"
  doAssert v.toJson().fromJson(string) == v
  doAssert v.toJson().fromJson(string) == v

block:
  var s = """ "new\nline" """
  var v = s.fromJson(string)
  doAssert v == "new\nline"
  doAssert v.toJson().fromJson(string) == v
  echo v.toJson().fromJson().toJson().fromJson()

block:
  var s = """ "quote\"inside" """
  var v = s.fromJson(string)
  doAssert v == "quote\"inside"
  doAssert v.toJson().fromJson(string) == v

block:
  var s = """ "special: \"\\\/\b\f\n\r\t chars" """
  var v = s.fromJson(string)
  doAssert v == "special: \"\\/\b\f\n\r\t chars"
  doAssert v.toJson().fromJson(string) == v

block:
  var s = """ "unicode: \u0020 \u0F88 \u1F21" """
  var v = s.fromJson(string)
  doAssert v == "unicode: \u0020 \u0F88 \u1F21"
  doAssert v.toJson().fromJson(string) == v
