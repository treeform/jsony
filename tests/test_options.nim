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

type
  TestObject = object
    name: string
    value: Option[int]

let objWithNull = TestObject(name: "Test", value: none(int))
let objWithoutNull = TestObject(name: "Test", value: some(123))

# Test dropNull = true
let optionsDropNull = SerializationOptions(dropNull: true)
let jsonDropNull = objWithNull.toJson(optionsDropNull)
doAssert jsonDropNull == "{\"name\":\"Test\"}"

# Test dropNull = false (default behavior)
let jsonKeepNull = objWithNull.toJson()
doAssert jsonKeepNull == "{\"name\":\"Test\",\"value\":null}"

# Test with a non-null value
let jsonNonNull = objWithoutNull.toJson(optionsDropNull)
doAssert jsonNonNull == "{\"name\":\"Test\",\"value\":123}"

type
  TestObjectWithDefaults = object
    name: string = "DefaultName"
    count: int = 0
    enabled: bool = false
    optionalValue: Option[int] = none(int)

let objWithDefaults = TestObjectWithDefaults(name: "CustomName", count: 5, enabled: true, optionalValue: some(10))
let objWithDefaultValues = TestObjectWithDefaults()

# Test dropDefault = true
let optionsDropDefault = SerializationOptions(dropDefault: true)

# Test with custom values (should not drop anything)
let jsonWithCustomValues = objWithDefaults.toJson(optionsDropDefault)
doAssert jsonWithCustomValues == "{\"name\":\"CustomName\",\"count\":5,\"enabled\":true,\"optionalValue\":10}"

# Test with default values (should drop all fields)
let jsonWithDefaultValues = objWithDefaultValues.toJson(optionsDropDefault)
doAssert jsonWithDefaultValues == "{}"

# Test with mixed values (should drop default fields)
let objMixed = TestObjectWithDefaults(name: "MixedName", count: 0, enabled: false, optionalValue: none(int))
let jsonMixed = objMixed.toJson(optionsDropDefault)
doAssert jsonMixed == "{\"name\":\"MixedName\"}"
