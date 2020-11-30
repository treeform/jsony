# JSONy

Real world json is never what you want. It might have extra fields that you don't care about. It might have missing fields signifying default values. It might change or grow new fields at any moment. Json might use camelCase or snake_case. It might use inconsistent naming.

With this library you can parse json your way, from the mess you get to the objects you want.

## No garbage.

Current standard module first parses json into JsonNodes and then turns the JsonNodes into objects you want. This is slower and creates unnecessary work for the garbage collector. This library skips the JsonNodes and creates the objects you want directly.

## Not strict.

Extra json fields are ignored and missing json fields keep their default values. Json is never exactly what you want.

```nim
type Entry1 = object
  color: string
var s = """{"extra":"foo"}"""
var v = fromJson[Entry1](s)
doAssert v.color == ""
```

## Has hooks.

### `proc newHook(foo: var ...)` Can be used to populate default values.

```nim
type
  Foo5 = object
    visible: string
    id: string
proc newHook(foo: var Foo5) =
  # Populates the object before its deserialized.
  foo.visible = "yes"

var s = """{"id":"123"}"""
var v = fromJson[Foo5](s)
doAssert v.id == "123"
doAssert v.visible == "yes"
```

### `proc enumHook[...](v: string): ...` Can be used to parse enums.

```nim
type Color2 = enum
  c2Red
  c2Blue
  c2Green

proc enumHook[Color2](v: string): Color2 =
  case v:
  of "RED": c2Red
  of "BLUE": c2Blue
  of "GREEN": c2Green
  else: c2Red

doAssert fromJson[Color2](""" "RED" """) == c2Red
doAssert fromJson[Color2](""" "BLUE" """) == c2Blue
doAssert fromJson[Color2](""" "GREEN" """) == c2Green
```