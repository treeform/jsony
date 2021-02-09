# JSONy - A loose, direct to object json parser and serializer with hooks.

Pure nim module with no other dependencies.

`nimble install jsony`

```nim
@[1, 2, 3].toJson() -> "[1,2,3]"
"[1,2,3]".fromJson(seq[int]) -> @[1, 2, 3]
```

Real world json is *never what you want*. It might have extra fields that you don't care about. It might have missing fields requiring default values. It might change or grow new fields at any moment. Json might use `camelCase` or `snake_case`. It might use inconsistent naming.

With this library you can use json your way, from the mess you get to the objects you want.

## Fast.

Currently the Nim standard module first parses or serializes json into JsonNodes and then turns the JsonNodes into your objects with the `to()` macro. This is slower and creates unnecessary work for the garbage collector. This library skips the JsonNodes and creates the objects you want directly.

Another speed up comes from not using `StringStream`. Stream has a function dispatch overhead because it has to be able to switch between `StringStream` or `FileStream` at runtime. Jsony skips the overhead and just directly reads or writes to memory buffers.

Another speed up comes from parsing and readings its own numbers directly from memory buffer. This allows it to bypass `string` allocations that `parseInt` or `$` create.


### Serialize speed
```
name ............................... min time      avg time    std dv  times
treeform/jsony ..................... 1.531 ms      2.779 ms    ±0.091   x100
status-im/nim-json-serialization ... 2.043 ms      3.448 ms    ±0.746   x100
planetis-m/eminim .................. 5.951 ms      9.305 ms    ±3.210   x100
disruptek/jason ................... 10.312 ms     13.471 ms    ±3.107   x100
nim std/json ...................... 12.551 ms     19.419 ms    ±4.039   x100
```

### Deserialize speed
```
name ............................... min time      avg time    std dv  times
treeform/jsony ..................... 6.724 ms     12.047 ms    ±3.694   x100
status-im/nim-json-serialization ... 7.119 ms     14.276 ms    ±2.033   x100
nim std/json ...................... 24.141 ms     38.741 ms    ±5.417   x100
planetis-m/eminim ................. 10.974 ms     18.355 ms    ±3.994   x100
```

Note: If you find a faster nim json parser or serializer let me know!

## Can parse or serializer most types:

* numbers and strings
* seq and arrays
* objects and ref objects
* options
* enums
* tuples
* characters
* `HashTable`s and `OrderedTable`s
* `HashSet`s and `OrderedSet`s
* json nodes
* and `parseHook()` enables you to parse any type!

## Not strict.

Extra json fields are ignored and missing json fields keep their default values.

```nim
type Entry1 = object
  color: string
var s = """{"extra":"foo"}"""
var v = s.fromJson(Entry1)
doAssert v.color == ""
```

## Converts snake_case to camelCase.

Nim usually uses `camelCase` for its variables, while a bunch of json in the wild uses `snake_case`. This library will convert `snake_case` to `camelCase` for you when reading json.

```nim
type Entry4 = object
  colorBlend: string

var v = """{"colorBlend":"red"}""".fromJson(Entry4)
doAssert v.colorBlend == "red"

v = """{"color_blend":"red"}""".fromJson(Entry4)
doAssert v.colorBlend == "red"
```

## Has hooks.

### `proc newHook()` Can be used to populate default values.

Sometimes the absence of a field means it should have a default value. Normally this would just be Nim's default value for the variable type but that isn't always what you want. With the newHook() you can initialize the object's defaults before the main parsing happens.

```nim
type
  Foo5 = object
    visible: string
    id: string
proc newHook(foo: var Foo5) =
  # Populates the object before its fully deserialized.
  foo.visible = "yes"

var s = """{"id":"123"}"""
var v = s.fromJson(s)
doAssert v.id == "123"
doAssert v.visible == "yes"
```

### `proc postHook()` Can be used to run code after the object is fully parsed.

Some times we need run some code after the object is created. For example to set other values based on values that where set but are not part of the json data. Maybe to sanitize the object or convert older versions to new versions. Here I need to retain the original size as I will be messing with the object's regular size:

```nim
type Sizer = object
  size: int
  originalSize: int

proc postHook(v: var Sizer) =
  v.originalSize = v.size

var sizer = """{"size":10}""".fromJson(Sizer)
doAssert sizer.size == 10
doAssert sizer.originalSize == 10
```

### `proc enumHook()` Can be used to parse enums.

In the wild json enum names almost never match to Nim enum names which usually have a prefix. The enumHook() allows you to rename the enums to your internal names.

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

doAssert """ "RED" """.fromJson(Color2) == c2Red
doAssert """ "BLUE" """.fromJson(Color2) == c2Blue
doAssert """ "GREEN" """.fromJson(Color2) == c2Green
```

### `proc renameHook()` Can be used to rename fields at run time.

In the wild json field names can be reserved words such as type, class, or array. With the renameHook you can rename fields to what you want.

```nim
type Node = ref object
  kind: string

proc renameHook(v: var Node, fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

var node = """{"type":"root"}""".fromJson(Node)
doAssert node.kind == "root"
```

### `proc parseHook()` Can be used to do anything.

Json can't store dates, so they are usually stored as strings. You can use
`parseHook()` to override default parsing and parse `DateTime` as a `string`:

```nim
proc parseHook(s: string, i: var int, v: var DateTime) =
  var str: string
  parseHook(s, i, str)
  v = parse(str, "yyyy-MM-dd hh:mm:ss")

var dt = """ "2020-01-01 00:00:00" """.fromJson(DateTime)
```

Sometimes json gives you an object of entries with their id as keys, but you might want it as a sequence with ids inside the objects. You can handle this and many other scenarios with `parseHook()`:

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

proc parseHook(s: string, i: var int, v: var seq[Entry]) =
  var table: Table[string, Entry]
  parseHook(s, i, table)
  for k, entry in table.mpairs:
    entry.id = k
    v.add(entry)

let s = data.fromJson(seq[Entry])
```

Gives us:
```
@[
  (id: "1", count: 12, filled: 11),
  (id: "2", count: 66, filled: 0),
  (id: "3", count: 99, filled: 99)
]"""
```

### `proc dumpHook()` Can be used to serializer into custom representation.

Just like reading custom data types you can also write data types with `dumpHook`.

```nim
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
let s = f.toJson()
```

Gives us:
```
"10/13"
```

## Static writing with `toStaticJson`.

Some times you have or const json and you want to write it in a static way. There is a special function for that:

```nim
thing.toStaticJson()
```

Make sure `thing` is a `static` or a `const` value and you will get a compile time string with your JSON.

## Full support for case variant objects.

Case variant objects like this are fully supported:

```nim
type RefNode = ref object
  case kind: NodeNumKind  # The ``kind`` field is the discriminator.
  of nkInt: intVal: int
  of nkFloat: floatVal: float
```

The discriminator do no have to come first, if they do come in the middle this library will scan the object, find the discriminator field, then rewind and parse the object normally.

## Full support for json-in-json.

Some times your json objects could contain arbitrary json structures,
maybe event user defined, that could only be walked as json nodes. This library allows you to parse json-in-json were you parse some of the structure as real nim objects but leave some parts of it as Json Nodes to be walked later with code:

```nim
type Entry = object
  name: string
  data: JsonNode

"""
{
  "name":"json-in-json",
  "data":{
    "random-data":"here",
    "number":123,
    "number2":123.456,
    "array":[1,2,3],
    "active":true,
    "null":null
  }
}""".fromJson(Entry)
```
