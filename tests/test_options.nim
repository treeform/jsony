import jsony, options

var
  a: Option[int] = some(123)
  b: Option[int]

doAssert a.toJson() == """123"""
doAssert b.toJson() == """null"""

doAssert """1""".fromJson(Option[int]) == some(1)
doAssert """null""".fromJson(Option[int]) == none(int)

proc check[T](v: T) =
  var v2 = some(v)
  var v3 = none(type(v))
  doAssert v2.toJson.fromJson(Option[T]) == v2
  doAssert v3.toJson.fromJson(Option[T]) == v3

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
    key: Option[int]
var test = """{ "key": null }""".fromJson(Test)
doAssert test.key.isNone == true
var test2 = """{ "key": 2 }""".fromJson(Test)
doAssert test2.key.isNone == false
doAssert test2.key.get == 2
