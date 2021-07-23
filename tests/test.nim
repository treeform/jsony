import json, jsony, strutils, options, tables, times

# Test arrays.

block:
  var s = "[1, 2, 3]"
  var v = s.fromJson(array[3, int])
  doAssert v[0] == 1
  doAssert v[1] == 2
  doAssert v[2] == 3

block:
  var s = "[1.5, 2.25, 3.0]"
  var v = s.fromJson(array[3, float32])
  doAssert v[0] == 1.5
  doAssert v[1] == 2.25
  doAssert v[2] == 3.0

block:
  var s = """["no", "yes"]"""
  var v = s.fromJson(array[2, string])
  doAssert v[0] == "no"
  doAssert v[1] == "yes"

block:
  var s = """["no", "yes"]"""
  var v = s.fromJson(ref array[2, string])
  doAssert v[0] == "no"
  doAssert v[1] == "yes"

block:
  var s = "null"
  var v = s.fromJson(ref array[2, string])
  doAssert v == nil

# Test char.

doAssert """ "a" """.fromJson(char) == 'a'
doAssert """["a"]""".fromJson(seq[char]) == @['a']
doAssert """["a", "b", "c"]""".fromJson(seq[char]) == @['a', 'b', 'c']
doAssert 'a'.toJson() == """"a""""
doAssert 'b'.toJson() == """"b""""

# Test enums

type Color = enum
  cRed
  cBlue
  cGreen

doAssert "0".fromJson(Color) == cRed
doAssert "1".fromJson(Color) == cBlue
doAssert "2".fromJson(Color) == cGreen

doAssert """ "cRed" """.fromJson(Color) == cRed
doAssert """ "cBlue" """.fromJson(Color) == cBlue
doAssert """ "cGreen" """.fromJson(Color) == cGreen

type Color2 = enum
  c2Red
  c2Blue
  c2Green

proc enumHook(s: string, v: var Color2) =
  v = case s:
  of "RED": c2Red
  of "BLUE": c2Blue
  of "GREEN": c2Green
  else: c2Red

doAssert """ "RED" """.fromJson(Color2) == c2Red
doAssert """ "BLUE" """.fromJson(Color2) == c2Blue
doAssert """ "GREEN" """.fromJson(Color2) == c2Green

# Test numbers.

block:
  doAssert "true".fromJson(bool) == true
  doAssert "false".fromJson(bool) == false
  doAssert " true  ".fromJson(bool) == true
  doAssert "  false    ".fromJson(bool) == false

  doAssert "1".fromJson(int) == 1
  doAssert "12".fromJson(int) == 12
  doAssert "  123  ".fromJson(int) == 123

  doAssert " 123 ".fromJson(int8) == 123
  doAssert " 123 ".fromJson(uint8) == 123
  doAssert " 123 ".fromJson(int16) == 123
  doAssert " 123 ".fromJson(uint16) == 123
  doAssert " 123 ".fromJson(int32) == 123
  doAssert " 123 ".fromJson(uint32) == 123
  doAssert " 123 ".fromJson(int64) == 123
  doAssert " 123 ".fromJson(uint64) == 123

  doAssert " -99 ".fromJson(int8) == -99
  doAssert " -99 ".fromJson(int16) == -99
  doAssert " -99 ".fromJson(int32) == -99
  doAssert " -99 ".fromJson(int64) == -99

  doAssert " +99 ".fromJson(int8) == 99
  doAssert " +99 ".fromJson(int16) == 99
  doAssert " +99 ".fromJson(int32) == 99
  doAssert " +99 ".fromJson(int64) == 99

  doAssert " 1.25 ".fromJson(float32) == 1.25
  doAssert " 1.25 ".fromJson(float32) == 1.25
  doAssert " +1.25 ".fromJson(float64) == 1.25
  doAssert " +1.25 ".fromJson(float64) == 1.25
  doAssert " -1.25 ".fromJson(float64) == -1.25
  doAssert " -1.25 ".fromJson(float64) == -1.25

  doAssert " 1.34E3 ".fromJson(float32) == 1.34E3
  doAssert " 1.34E3 ".fromJson(float32) == 1.34E3
  doAssert " +1.34E3 ".fromJson(float64) == 1.34E3
  doAssert " +1.34E3 ".fromJson(float64) == 1.34E3
  doAssert " -1.34E3 ".fromJson(float64) == -1.34E3
  doAssert " -1.34E3 ".fromJson(float64) == -1.34E3

block:
  doAssert "[1, 2, 3]".fromJson(seq[int]) == @[1, 2, 3]
  doAssert """["hi", "bye", "maybe"]""".fromJson(seq[string]) ==
    @["hi", "bye", "maybe"]
  doAssert """[["hi", "bye"], ["maybe"], []]""".fromJson(seq[seq[string]]) ==
    @[@["hi", "bye"], @["maybe"], @[]]

when not defined(js):
  doAssertRaises JsonyError:
    var
      s = ""
      i = 0
      n: uint64
    parseHook(s, i, n)

for i in 0 .. 10000:
  var s = ""
  dumpHook(s, i)
  doAssert $i == s

for i in 0 .. 10000:
  var s = $i
  var idx = 0
  var v: int
  parseHook(s, idx, v)
  doAssert i == v

# Test json-in-json.

block:
  type Entry = object
    name: string
    data: JsonNode

  var entry = Entry()
  entry.name = "json-in-json"
  entry.data = %*{
    "random-data": "here",
    "number": 123,
    "number2": 123.456,
    "array": @[1, 2, 3],
    "active": true,
    "null": nil
  }

  doAssert entry.toJson() == """{"name":"json-in-json","data":{"random-data":"here","number":123,"number2":123.456,"array":[1,2,3],"active":true,"null":null}}"""
  doAssert $entry.toJson.fromJson(Entry) == """(name: "json-in-json", data: {"random-data":"here","number":123,"number2":123.456,"array":[1,2,3],"active":true,"null":null})"""

  let s = """{"name":"json-in-json","data":{"random-data":"here","number":123,"number2":123.456,"array":[1,2,3],"active":true,"null":null}}"""
  doAssert $s.fromJson() == """{"name":"json-in-json","data":{"random-data":"here","number":123,"number2":123.456,"array":[1,2,3],"active":true,"null":null}}"""

  let ns = """[123, +123, -123, 123.456, +123.456, -123.456, 123.456E9, +123.456E9, -123.456E9]"""
  doAssert $ns.fromJson() == """[123,123,-123,123.456,123.456,-123.456,123456000000.0,123456000000.0,-123456000000.0]"""

# Test objects.

block:
  type Entry1 = object
    color: string
  var s = "{}"
  var v = s.fromJson(Entry1)
  doAssert v.color == ""

block:
  type Foo2 = ref object
    field: string
    a: string
    ratio: float32
  var s = """{"field":"is here", "a":"b", "ratio":22.5}"""
  var v = s.fromJson(Foo2)
  doAssert v.field == "is here"
  doAssert v.a == "b"
  doAssert v.ratio == 22.5

type
  Bar3 = ref object
    name: string
  Foo3 = ref object
    id: string
    bar: Bar3
var s = """{"id":"123", "bar":{"name":"abc"}}"""
var v = s.fromJson(Foo3)
doAssert v.id == "123"
doAssert v.bar.name == "abc"

# hooks can't be inside blocks

type
  Bar4 = ref object
    visible: string
    name: string
  Foo4 = ref object
    visible: string
    id: string
    bar: Bar4

proc newHook(foo: var Foo4) =
  foo = Foo4()
  foo.visible = "yes"

block:
  var s = """{"id":"123", "bar":{"name":"abc", "visible": "yes"}}"""
  var v = s.fromJson(Foo4)
  doAssert v.id == "123"
  doAssert v.visible == "yes"
  doAssert v.bar.name == "abc"
  doAssert v.bar.visible == "yes"

# Hooks can't be inside blocks.
type
  Foo5 = object
    visible: string
    id: string
proc newHook(foo: var Foo5) =
  foo.visible = "yes"

block:
  var s = """{"id":"123", "visible": "yes"}"""
  var v = s.fromJson(Foo5)
  doAssert v.id == "123"
  doAssert v.visible == "yes"

block:
  var s = """{"id":"123"}"""
  var v = s.fromJson(Foo5)
  doAssert v.id == "123"
  doAssert v.visible == "yes"

block:
  var s = """{"id":"123", "visible": "no"}"""
  var v = s.fromJson(Foo5)
  doAssert v.id == "123"
  doAssert v.visible == "no"

block:
  type Entry2 = object
    color: string
  var s = """[{}, {"color":"red"}]"""
  var v = s.fromJson(seq[Entry2])
  doAssert v.len == 2
  doAssert v[0].color == ""
  doAssert v[1].color == "red"

block:
  ## Skip extra fields
  type Entry3 = object
    color: string
  var s = """[{"id":123}, {"color":"red", "id":123}, {"ex":[{"color":"red"}]}]"""
  var v = s.fromJson(seq[Entry3])
  doAssert v.len == 3
  doAssert v[0].color == ""
  doAssert v[1].color == "red"
  doAssert v[2].color == ""

block:
  ## Skip extra fields
  type Entry4 = object
    colorBlend: string

  var v = """{"colorBlend":"red"}""".fromJson(Entry4)
  doAssert v.colorBlend == "red"

  v = """{"color_blend":"red"}""".fromJson(Entry4)
  doAssert v.colorBlend == "red"

proc snakeCase(s: string): string =
  var prevCap = false
  for i, c in s:
    if c in {'A'..'Z'}:
      if result.len > 0 and result[^1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
      result.add c.toLowerAscii()
    else:
      prevCap = false
      result.add c

doAssert snakeCase("colorRule") == "color_rule"
doAssert snakeCase("ColorRule") == "color_rule"
doAssert snakeCase("Color_Rule") == "color_rule"
doAssert snakeCase("color_Rule") == "color_rule"
doAssert snakeCase("color_rule") == "color_rule"
doAssert snakeCase("httpGet") == "http_get"
doAssert snakeCase("restAPI") == "rest_api"

block:
  type Entry5 = object
    color: string
  var s = "null"
  var v = s.fromJson(Entry5)
  doAssert v.color == ""

block:
  type Entry6 = ref object
    color: string
  var s = "null"
  var v = s.fromJson(Entry6)
  doAssert v == nil

type Node = ref object
  kind: string

proc renameHook(v: var Node, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

var node = """{"type":"root"}""".fromJson(Node)
doAssert node.kind == "root"

type Sizer = object
  size: int
  originalSize: int

proc postHook(v: var Sizer) =
  v.originalSize = v.size

var sizer = """{"size":10}""".fromJson(Sizer)
doAssert sizer.size == 10
doAssert sizer.originalSize == 10

block:

  type
    NodeNumKind = enum  # the different node types
      nkInt,          # a leaf with an integer value
      nkFloat,        # a leaf with a float value
    RefNode = ref object
      active: bool
      case kind: NodeNumKind  # the ``kind`` field is the discriminator
      of nkInt: intVal: int
      of nkFloat: floatVal: float
    ValueNode = object
      active: bool
      case kind: NodeNumKind  # the ``kind`` field is the discriminator
      of nkInt: intVal: int
      of nkFloat: floatVal: float

  block:
    var nodeNum = RefNode(kind: nkFloat, active: true, floatVal: 3.14)
    var nodeNum2 = RefNode(kind: nkInt, active: false, intVal: 42)
    doAssert nodeNum.toJson.fromJson(type(nodeNum)).floatVal == nodeNum.floatVal
    doAssert nodeNum2.toJson.fromJson(type(nodeNum2)).intVal == nodeNum2.intVal
    doAssert nodeNum.toJson.fromJson(type(nodeNum)).active == nodeNum.active
    doAssert nodeNum2.toJson.fromJson(type(nodeNum2)).active == nodeNum2.active

  block:
    # Test discriminator Field Name not being first.
    let
      a = """{"active":true,"kind":"nkFloat","floatVal":3.14}""".fromJson(RefNode)
      b = """{"floatVal":3.14,"active":true,"kind":"nkFloat"}""".fromJson(RefNode)
      c = """{"kind":"nkFloat","floatVal":3.14,"active":true}""".fromJson(RefNode)
    doAssert a.kind == nkFloat
    doAssert b.kind == nkFloat
    doAssert c.kind == nkFloat

  block:
    # Test discriminator field name not being there.
    doAssertRaises JsonyError:
      let
        a = """{"active":true,"floatVal":3.14}""".fromJson(RefNode)

  block:
    var nodeNum = ValueNode(kind: nkFloat, active: true, floatVal: 3.14)
    var nodeNum2 = ValueNode(kind: nkInt, active: false, intVal: 42)
    doAssert nodeNum.toJson.fromJson(type(nodeNum)).floatVal == nodeNum.floatVal
    doAssert nodeNum2.toJson.fromJson(type(nodeNum2)).intVal == nodeNum2.intVal
    doAssert nodeNum.toJson.fromJson(type(nodeNum)).active == nodeNum.active
    doAssert nodeNum2.toJson.fromJson(type(nodeNum2)).active == nodeNum2.active

  block:
    # Test discriminator Field Name not being first.
    let
      a = """{"active":true,"kind":"nkFloat","floatVal":3.14}""".fromJson(ValueNode)
      b = """{"floatVal":3.14,"active":true,"kind":"nkFloat"}""".fromJson(ValueNode)
      c = """{"kind":"nkFloat","floatVal":3.14,"active":true}""".fromJson(ValueNode)
    doAssert a.kind == nkFloat
    doAssert b.kind == nkFloat
    doAssert c.kind == nkFloat

  block:
    # Test discriminator field name not being there.
    doAssertRaises JsonyError:
      let
        a = """{"active":true,"floatVal":3.14}""".fromJson(ValueNode)

type
    NodeNumKind = enum  # the different node types
      nkInt,          # a leaf with an integer value
      nkFloat,        # a leaf with a float value
    RefNode = ref object
      active: bool
      case kind: NodeNumKind  # the ``kind`` field is the discriminator
      of nkInt: intVal: int
      of nkFloat: floatVal: float
    ValueNode = object
      active: bool
      case kind: NodeNumKind  # the ``kind`` field is the discriminator
      of nkInt: intVal: int
      of nkFloat: floatVal: float

proc renameHook*(v: var RefNode|ValueNode, fieldName: var string) =
  # rename``type`` field name to ``kind``
  if fieldName == "type":
    fieldName = "kind"

# Test renameHook and discriminator Field Name not being first.
block:
  let
    a = """{"active":true,"type":"nkFloat","floatVal":3.14}""".fromJson(RefNode)
    b = """{"floatVal":3.14,"active":true,"type":"nkFloat"}""".fromJson(RefNode)
    c = """{"type":"nkFloat","floatVal":3.14,"active":true}""".fromJson(RefNode)
  doAssert a.kind == nkFloat
  doAssert b.kind == nkFloat
  doAssert c.kind == nkFloat

block:
  let
    a = """{"active":true,"type":"nkFloat","floatVal":3.14}""".fromJson(ValueNode)
    b = """{"floatVal":3.14,"active":true,"type":"nkFloat"}""".fromJson(ValueNode)
    c = """{"type":"nkFloat","floatVal":3.14,"active":true}""".fromJson(ValueNode)
  doAssert a.kind == nkFloat
  doAssert b.kind == nkFloat
  doAssert c.kind == nkFloat

# Test options.

var
  a: Option[int] = some(123)
  b: Option[int]

doAssert a.toJson() == """123"""
doAssert b.toJson() == """null"""

doAssert $("""1""".fromJson(Option[int])) == "Some(1)"
doAssert $("""null""".fromJson(Option[int])) == "None[int]"

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
check([1,2,3])
check(@[1,2,3])

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

# Test parseHook.

type Fraction = object
  numerator: int
  denominator: int

proc parseHook(s: string, i: var int, v: var Fraction) =
  ## Instead of looking for fraction object look for a string.
  var str: string
  parseHook(s, i, str)
  let arr = str.split("/")
  v = Fraction()
  v.numerator = parseInt(arr[0])
  v.denominator = parseInt(arr[1])

var frac = """ "1/3" """.fromJson(Fraction)
doAssert frac.numerator == 1
doAssert frac.denominator == 3

proc parseHook(s: string, i: var int, v: var DateTime) =
  var str: string
  parseHook(s, i, str)
  v = parse(str, "yyyy-MM-dd hh:mm:ss")

var dt = """ "2020-01-01 00:00:00" """.fromJson(DateTime)
doAssert dt.year == 2020

type FillEntry = object
  id: string
  count: int
  filled: int

let data = """{
  "1": {"count":12, "filled": 11},
  "2": {"count":66, "filled": 0},
  "3": {"count":99, "filled": 99}
}"""

proc parseHook(s: string, i: var int, v: var seq[FillEntry]) =
  var table: Table[string, FillEntry]
  parseHook(s, i, table)
  for k, entry in table.mpairs:
    entry.id = k
    v.add(entry)

let s2 = data.fromJson(seq[FillEntry])
doAssert type(s2) is seq[FillEntry]
doAssert $s2 == """@[(id: "1", count: 12, filled: 11), (id: "2", count: 66, filled: 0), (id: "3", count: 99, filled: 99)]"""
