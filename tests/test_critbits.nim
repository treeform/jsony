import jsony, strutils, critbits

block:
  var v: CritBitTree[void] = ["kitten", "puppy"].toCritBitTree

  var str = v.toJson()
  doAssert v.len == 2
  doAssert v.toJson() == """["kitten","puppy"]"""

  v = str.fromJson(v.type)
  doAssert v.contains("kitten")
  doAssert v.contains("puppy")

block:
  var v: CritBitTree[int] = {"one": 1, "two": 2}.toCritBitTree

  var str = v.toJson()
  doAssert(str == """{"one":1,"two":2}""")
  doAssert($(str.fromJson(v.type)) == $v)

  v = str.fromJson(v.type)
  doAssert v.contains("one")
  doAssert v.contains("two")

block:
  type Entry = object
    color: string
  var s = """{
    "a": {"color":"red"},
    "b": {"color":"green"},
    "c": {"color":"blue"}
  }"""
  var v = s.fromJson(CritBitTree[Entry])
  doAssert v.len == 3
  doAssert v["a"].color == "red"
  doAssert v["b"].color == "green"
  doAssert v["c"].color == "blue"

block:
  type Entry = ref object
    case b: bool
    of true:
      t: string
    of false:
      f: int
    node: Entry

  var str = """{"entry":{"b":true,"t":"yes","node":{"b":false,"f":0,"node":null}}}"""
  var v = 
    {"entry":
      Entry(
        b: true,
        t: "yes",
        node: Entry(b: false, f: 0)
      )
    }.toCritBitTree
  doAssert v.toJson() == str

  v = str.fromJson(CritBitTree[Entry])
  doAssert v.len == 1
  doAssert v.contains("entry")
  doAssert v["entry"].b == true
  doAssert v["entry"].t == "yes"
  doAssert v["entry"].node.b == false
  doAssert v["entry"].node.f == 0
  doAssert v["entry"].node.node == nil
