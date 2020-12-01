import jsony

block:
  type Entry1 = object
    color: string
  var s = "{}"
  var v = fromJson[Entry1](s)
  doAssert v.color == ""

block:
  type Foo2 = ref object
    field: string
    a: string
    ratio: float32
  var s = """{"field":"is here", "a":"b", "ratio":22.5}"""
  var v = fromJson[Foo2](s)
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
var v = fromJson[Foo3](s)
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
  var v = fromJson[Foo4](s)
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
  var v = fromJson[Foo5](s)
  doAssert v.id == "123"
  doAssert v.visible == "yes"

block:
  var s = """{"id":"123"}"""
  var v = fromJson[Foo5](s)
  doAssert v.id == "123"
  doAssert v.visible == "yes"

block:
  var s = """{"id":"123", "visible": "no"}"""
  var v = fromJson[Foo5](s)
  doAssert v.id == "123"
  doAssert v.visible == "no"

block:
  type Entry2 = object
    color: string
  var s = """[{}, {"color":"red"}]"""
  var v = fromJson[seq[Entry2]](s)
  doAssert v.len == 2
  doAssert v[0].color == ""
  doAssert v[1].color == "red"


block:
  ## Skip extra fields
  type Entry3 = object
    color: string
  var s = """[{"id":123}, {"color":"red", "id":123}, {"ex":[{"color":"red"}]}]"""
  var v = fromJson[seq[Entry3]](s)
  doAssert v.len == 3
  doAssert v[0].color == ""
  doAssert v[1].color == "red"
  doAssert v[2].color == ""

block:
  ## Skip extra fields
  type Entry4 = object
    colorBlend: string

  var v = fromJson[Entry4]("""{"colorBlend":"red"}""")
  doAssert v.colorBlend == "red"

  v = fromJson[Entry4]("""{"color_blend":"red"}""")
  doAssert v.colorBlend == "red"

import strutils
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
  var v = fromJson[Entry5](s)
  doAssert v.color == ""

block:
  type Entry6 = ref object
    color: string
  var s = "null"
  var v = fromJson[Entry6](s)
  doAssert v == nil
