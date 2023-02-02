import json, jsony, strutils, tables

proc match[T](what: T) =
  doAssert what.toJson() == $(%what)

doAssert 1.uint8.toJson() == "1"
doAssert 1.uint16.toJson() == "1"
doAssert 1.uint32.toJson() == "1"
doAssert 1.int8.toJson() == "1"
doAssert 1.int16.toJson() == "1"
doAssert 1.int32.toJson() == "1"
doAssert 3.14.float64.toJson() == "3.14"

when not defined(js):
  doAssert 1.int64.toJson() == "1"
  doAssert 1.uint64.toJson() == "1"
  doAssert 3.14.float32.toJson() == "3.140000104904175"

match 1
match 3.14.float32
match 3.14.float64

doAssert [1, 2, 3].toJson() == "[1,2,3]"
doAssert @[1, 2, 3].toJson() == "[1,2,3]"

match [1, 2, 3]
match @[1, 2, 3]

doAssert true.toJson == "true"
doAssert false.toJson == "false"

doAssert 'a'.toJson == "\"a\""
match "hi there"
match "hi\nthere\b\f\n\r\t"
match "как дела"
match """ "quote\"inside" """

block:
  type
    Obj = object
      a: int
      b: float
      c: string
  var obj = Obj()
  doAssert obj.toJson() == """{"a":0,"b":0.0,"c":""}"""
  match obj

block:
  type
    Obj = ref object
      a: int
      b: float
      c: string
  var obj = Obj()
  doAssert obj.toJson() == """{"a":0,"b":0.0,"c":""}"""
  match obj

  var obj2: Obj
  doAssert obj2.toJson() == "null"
  match obj

var t = (1, 2.2, "hi")
doAssert t.toJson() == """[1,2.2,"hi"]"""

var tb: Table[string, int]
tb["hi"] = 1
tb["bye"] = 2
doAssert tb.toJson() == """{"hi":1,"bye":2}"""

type Fraction = object
  numerator: int
  denominator: int

proc dumpHook(s: var string, v: Fraction) =
  ## Output fraction type as a string "x/y".
  s.add '"'
  s.add $v.numerator
  s.add '/'
  s.add $v.denominator
  s.add '"'

var f = Fraction(numerator: 10, denominator: 13)
doAssert f.toJson() == "\"10/13\""

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

  var
    refNode1 = RefNode(kind: nkFloat, active: true, floatVal: 3.14)
    refNode2 = RefNode(kind: nkInt, active: false, intVal: 42)

    valueNode1 = ValueNode(kind: nkFloat, active: true, floatVal: 3.14)
    valueNode2 = ValueNode(kind: nkInt, active: false, intVal: 42)

  doAssert refNode1.toJson() == """{"active":true,"kind":"nkFloat","floatVal":3.14}"""
  doAssert refNode2.toJson() == """{"active":false,"kind":"nkInt","intVal":42}"""
  doAssert valueNode1.toJson() == """{"active":true,"kind":"nkFloat","floatVal":3.14}"""
  doAssert valueNode2.toJson() == """{"active":false,"kind":"nkInt","intVal":42}"""
