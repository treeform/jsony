import jsony, tables

block:

  var s = "{}"
  var v = fromJson[Table[string, int]](s)
  doAssert v.len == 0

block:
  var s = """{"a":2}"""
  var v = fromJson[Table[string, int]](s)
  doAssert v.len == 1
  doAssert v["a"] == 2

block:
  var s = """{"a":2, "b":3, "c" : 4}"""
  var v = fromJson[Table[string, uint8]](s)
  doAssert v.len == 3
  doAssert v["a"] == 2
  doAssert v["b"] == 3
  doAssert v["c"] == 4

block:
  type Entry = object
    color: string
  var s = """{
    "a": {"color":"red"},
    "b": {"color":"green"},
    "c": {"color":"blue"}
  }"""
  var v = fromJson[Table[string, Entry]](s)
  doAssert v.len == 3
  doAssert v["a"].color == "red"
  doAssert v["b"].color == "green"
  doAssert v["c"].color == "blue"
