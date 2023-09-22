import std/json, jsony, std/unicode

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
  doAssert v.toJson().fromJson().toJson().fromJson() == newJString("new\nline")

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

block:
  # https://github.com/treeform/jsony/issues/45
  # A string with 🔒 emoji encoded both as normal UTF-8 and as a surrogate pair
  type
    TestObj = object
      content: string
  let
    raw = """{"content":"\uD83D\uDD12🔒"}"""
    parsed = raw.fromJson(TestObj)
    parsedStd = parseJson(raw).to(TestObj)
  echo "jsony - ", parsed.content
  echo "std/json - ", parsedStd.content
  doAssert parsed.content == parsedStd.content

  let
    raw2 = """{"content":"\u00A1\uD835\uDC7D\uD835\uDC96\uD835\uDC86\uD835\uDC8D\uD835\uDC97\uD835\uDC86\uD835\uDC8F \uD835\uDC8F\uD835\uDC96\uD835\uDC86\uD835\uDC94\uD835\uDC95\uD835\uDC93\uD835\uDC90\uD835\uDC94 \uD835\uDC89\uD835\uDC8A\uD835\uDC8F\uD835\uDC84\uD835\uDC89\uD835\uDC82\uD835\uDC94!"}"""
    parsed2 = raw2.fromJson(TestObj)
    parsedStd2 = parseJson(raw2).to(TestObj)
  echo "jsony - ", parsed2.content
  echo "std/json - ", parsedStd2.content
  doAssert parsed2.content == parsedStd2.content

block:
  var s = "\"\\u00\""
  doAssertRaises jsony.JsonError:
    discard fromJson(s, string)

block:
  var s = "\"\\"
  doAssertRaises jsony.JsonError:
    discard fromJson(s, string)

block:
  var s = ""
  s.add cast[char](0b11000000)
  doAssert s.toJson() == "\"" & Rune(0xfffd).toUTF8() & "\""

block:
  var s = "abc"
  s.add cast[char](0b11000000)
  s.add "def"
  doAssert s.toJson() == "\"abc" & Rune(0xfffd).toUTF8() & "def\""

block:
  var s = "abc🔒"
  s.add cast[char](0b11000000)
  s.add "def"
  doAssert s.toJson() == "\"abc🔒" & Rune(0xfffd).toUTF8() & "def\""

block:
  var s = "\"" & Rune(0xfffd).toUTF8() & "\""
  doAssert fromJson(s, string).toJson() == s

block:
  var s: string
  s.add "\""
  s.add cast[char](0b11000000)
  s.add "\""
  doAssertRaises jsony.JsonError:
    discard fromJson(s, string)
