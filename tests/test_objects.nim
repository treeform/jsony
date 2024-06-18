import jsony, strutils

block:
  type Entry1 = object
    color: string
  var s = "{}"
  var v = s.fromJson(Entry1)
  doAssert v.color == ""

when NimMajor >= 2: # Default field values are only supported in Nim 2.0+
  block:
    type Frog = object
      legs: int = 4

    var s = "{}"
    var f = s.fromJson(Frog)
    # Make sure the default value is deserialized correctly.
    doAssert f.legs == 4

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
    NodeNumKind = enum # the different node types
      nkInt,           # a leaf with an integer value
      nkFloat,         # a leaf with a float value
    RefNode = ref object
      active: bool
      case kind: NodeNumKind # the ``kind`` field is the discriminator
      of nkInt: intVal: int
      of nkFloat: floatVal: float
    ValueNode = object
      active: bool
      case kind: NodeNumKind # the ``kind`` field is the discriminator
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
    let
      a = """{"active":true,"intVal":42}""".fromJson(RefNode)
    doAssert a.kind == nkInt

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
    let
      a = """{"active":true,"intVal":42}""".fromJson(ValueNode)
    doAssert a.kind == nkInt

type
  NodeNumKind = enum # the different node types
    nkInt,           # a leaf with an integer value
    nkFloat,         # a leaf with a float value
  RefNode = ref object
    active: bool
    case kind: NodeNumKind # the ``kind`` field is the discriminator
    of nkInt: intVal: int
    of nkFloat: floatVal: float
  ValueNode = object
    active: bool
    case kind: NodeNumKind # the ``kind`` field is the discriminator
    of nkInt: intVal: int
    of nkFloat: floatVal: float

proc renameHook*(v: var RefNode|ValueNode, fieldName: var string) =
  # rename``type`` field name to ``kind``
  if fieldName == "type":
    fieldName = "kind"

# Test renameHook and discriminator Field Name not being first/missing.
block:
  let
    a = """{"active":true,"type":"nkFloat","floatVal":3.14}""".fromJson(RefNode)
    b = """{"floatVal":3.14,"active":true,"type":"nkFloat"}""".fromJson(RefNode)
    c = """{"type":"nkFloat","floatVal":3.14,"active":true}""".fromJson(RefNode)
    d = """{"active":true,"intVal":42}""".fromJson(RefNode)
  doAssert a.kind == nkFloat
  doAssert b.kind == nkFloat
  doAssert c.kind == nkFloat
  doAssert d.kind == nkInt

block:
  let
    a = """{"active":true,"type":"nkFloat","floatVal":3.14}""".fromJson(ValueNode)
    b = """{"floatVal":3.14,"active":true,"type":"nkFloat"}""".fromJson(ValueNode)
    c = """{"type":"nkFloat","floatVal":3.14,"active":true}""".fromJson(ValueNode)
    d = """{"active":true,"intVal":42}""".fromJson(ValueNode)
  doAssert a.kind == nkFloat
  doAssert b.kind == nkFloat
  doAssert c.kind == nkFloat
  doAssert d.kind == nkInt

# test https://forum.nim-lang.org/t/7619

import jsony
type
  FooBar = object
    `Foo Bar`: string

const jsonString = "{\"Foo Bar\": \"Hello World\"}"

proc renameHook*(v: var FooBar, fieldName: var string) =
  if fieldName == "Foo Bar":
    fieldName = "FooBar"

echo jsonString.fromJson(FooBar)
