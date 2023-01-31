import jsony

proc newRef[T](v: T): ref T =
  new(result)
  result[] = v

var
  a: ref int = newRef(123)
  b: ref int

doAssert a.toJson() == """123"""
doAssert b.toJson() == """null"""

when not defined(js):
  # JS has a bug with ref ints: https://github.com/nim-lang/Nim/issues/21317
  doAssert $(fromJson("""1""", ref int)[]) == "1"
  doAssert fromJson("""null""", ref int) == nil

  proc check[T](v: T) =
    var v2: ref T = newRef(v)
    var v3: ref T = nil
    doAssert v2.toJson.fromJson(ref T)[] == v2[]
    doAssert v3.toJson.fromJson(ref T) == nil

  check(1.int)
  check(1.int8)
  check(1.int16)
  check(1.int32)
  check(1.int64)
  check(1.uint8)
  check(1.uint16)
  check(1.uint32)
  check(1.uint64)

  check("hello")
  check([1, 2, 3])
  check(@[1, 2, 3])

  type Entry = object
    color: string

  check(Entry())

type
  Test = object
    key: ref int
var test = """{ "key": null }""".fromJson(Test)
doAssert test.key == nil
var test2 = """{ "key": 2 }""".fromJson(Test)
doAssert test2.key != nil
doAssert test2.key[] == 2
