import jsony, tables

block:

  var s = "{}"
  var v = s.fromJson(Table[string, int])
  doAssert v.len == 0

block:
  var s = """{"a":2}"""
  var v = s.fromJson(Table[string, int])
  doAssert v.len == 1
  doAssert v["a"] == 2

block:
  var s = """{"a":2, "b":3, "c" : 4}"""
  var v = s.fromJson(Table[string, uint8])
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
  var v = s.fromJson(Table[string, Entry])
  doAssert v.len == 3
  doAssert v["a"].color == "red"
  doAssert v["b"].color == "green"
  doAssert v["c"].color == "blue"

block:
  type Entry = object
    color: string
  var s = """{
    "a": {"color":"red"},
    "b": {"color":"green"},
    "c": {"color":"blue"}
  }"""
  var v = s.fromJson(OrderedTableRef[string, Entry])
  doAssert v.len == 3
  doAssert v["a"].color == "red"
  doAssert v["b"].color == "green"
  doAssert v["c"].color == "blue"

block:
  doAssert {"j": 10, "s": 20, "o": 100, "n": 5000}.toJson() ==
    """{"j":10,"s":20,"o":100,"n":5000}"""

  doAssert {"j": "a", "s": "b", "o": "c", "n": "d"}.toJson() ==
    """{"j":"a","s":"b","o":"c","n":"d"}"""

  doAssert [{"j": "a"}].toJson() ==
    """[{"j":"a"}]"""
