# JSONy - A loose, direct to object json parser with hooks.

Real world json is *never what you want*. It might have extra fields that you don't care about. It might have missing fields requiring default values. It might change or grow new fields at any moment. Json might use `camelCase` or `snake_case`. It might use inconsistent naming.

With this library you can parse json your way, from the mess you get to the objects you want.

## Fast/No garbage.

Current standard module first parses json into JsonNodes and then turns the JsonNodes into your objects with the `to()` macro. This is slower and creates unnecessary work for the garbage collector. This library skips the JsonNodes and creates the objects you want directly.

## Can parse most object types:

* numbers and strings
* objects and ref objects
* enums
* tuples
* seq and arrays
* tables
* and `parseHook()` enables you to parse any type!

## Not strict.

Extra json fields are ignored and missing json fields keep their default values.

```nim
type Entry1 = object
  color: string
var s = """{"extra":"foo"}"""
var v = fromJson[Entry1](s)
doAssert v.color == ""
```

## Snake_case or CamelCase

Nim usually uses `camelCase` for its variables, while a bunch of json in the wild uses `snake_case`. This library will convert `snake_case` to `camelCase` for you when reading json.

```nim
type Entry4 = object
colorBlend: string

var v = fromJson[Entry4]("""{"colorBlend":"red"}""")
doAssert v.colorBlend == "red"

v = fromJson[Entry4]("""{"color_blend":"red"}""")
doAssert v.colorBlend == "red"
```

## Has hooks.

### `proc newHook()` Can be used to populate default values.

Some times absence of a field means it should have a default value. Normally this would just be Nim's default value for the variable type. But with the newHook() you can setup the object with defaults before the main parsing happens.

```nim
type
  Foo5 = object
    visible: string
    id: string
proc newHook(foo: var Foo5) =
  # Populates the object before its fully deserialized.
  foo.visible = "yes"

var s = """{"id":"123"}"""
var v = fromJson[Foo5](s)
doAssert v.id == "123"
doAssert v.visible == "yes"
```

### `proc enumHook()` Can be used to parse enums.

In wild json enums name almost never match to nim enum names that usually have a prefix. The enumHook() allows you to rename the enums to your internal names.

```nim
type Color2 = enum
  c2Red
  c2Blue
  c2Green

proc enumHook(v: string): Color2 =
  case v:
  of "RED": c2Red
  of "BLUE": c2Blue
  of "GREEN": c2Green
  else: c2Red

doAssert fromJson[Color2](""" "RED" """) == c2Red
doAssert fromJson[Color2](""" "BLUE" """) == c2Blue
doAssert fromJson[Color2](""" "GREEN" """) == c2Green
```

### `proc renameHook()` Can be used to rename fields at run time.

In wild json field names can be reserved words such as type, class, or array. With the renameHook you can rename fields to what you want on the type you need.

```nim
type Node = ref object
  kind: string

proc renameHook(v: var Node, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

var node = fromJson[Node]("""{"type":"root"}""")
doAssert node.kind == "root"
```

### `proc parseHook()` Can be used to do anything.

Json can't store dates, so they are usually stored as strings. You can use
`parseHook()` to override default parsing and parse date times as a string:

```nim
proc parseHook(s:string, i:var int, v: var DateTime) =
  var str: string
  parseHook(s, i, str)
  v = parse(str, "yyyy-MM-dd hh:mm:ss")

var dt = fromJson[DateTime](""" "2020-01-01 00:00:00" """)
```

Some times json gives you a object of entries with their id as keys, but you might want it as a sequence with ids inside the objects, again you can do anything with `parseHook()`:

```nim
type Entry = object
  id: string
  count: int
  filled: int

let data = """{
  "1": {"count":12, "filled": 11},
  "2": {"count":66, "filled": 0},
  "3": {"count":99, "filled": 99}
}"""

proc parseHook(s:string, i:var int, v: var seq[Entry]) =
  var table: Table[string, Entry]
  parseHook(s, i, table)
  for k, entry in table.mpairs:
    entry.id = k
    v.add(entry)

let s = fromJson[seq[Entry]](data)
```

Gives us:
```
@[
  (id: "1", count: 12, filled: 11),
  (id: "2", count: 66, filled: 0),
  (id: "3", count: 99, filled: 99)
]"""
```
