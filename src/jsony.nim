import jsony/objvar, strutils, tables, sets, unicode, json, options, parseutils, typetraits

type JsonError* = object of ValueError

const whiteSpace = {' ', '\n', '\t', '\r'}

when defined(release):
  {.push checks: off, inline.}

type
  SomeTable*[K, V] = Table[K, V] | OrderedTable[K, V] |
    TableRef[K, V] | OrderedTableRef[K, V]

  JsonyContext* = ref object
    data*: string
    i*: int

proc parseHook*[T](jx: JsonyContext, v: var seq[T])
proc parseHook*[T: enum](jx: JsonyContext, v: var T)
proc parseHook*[T: object|ref object](jx: JsonyContext, v: var T)
proc parseHook*[T](jx: JsonyContext, v: var SomeTable[string, T])
proc parseHook*[T](jx: JsonyContext, v: var (SomeSet[T]|set[T]))
proc parseHook*[T: tuple](jx: JsonyContext, v: var T)
proc parseHook*[T: array](jx: JsonyContext, v: var T)
proc parseHook*[T: not object](jx: JsonyContext, v: var ref T)
proc parseHook*(jx: JsonyContext, v: var JsonNode)
proc parseHook*(jx: JsonyContext, v: var char)
proc parseHook*[T: distinct](jx: JsonyContext, v: var T)

template error(jx: JsonyContext, msg: string) =
  ## Shortcut to raise an exception.
  raise newException(JsonError, msg & " At offset: " & $jx.i)

template eatSpace*(jx: JsonyContext) =
  ## Will consume whitespace.
  while jx.i < jx.data.len:
    let c = jx.data[jx.i]
    if c notin whiteSpace:
      break
    inc jx.i

template eatChar*(jx: JsonyContext, c: char) =
  ## Will consume space before and then the character `c`.
  ## Will raise an exception if `c` is not found.
  jx.eatSpace()
  if jx.i >= jx.data.len:
    error(jx, "Expected " & c & " but end reached.")
  if jx.data[jx.i] == c:
    inc jx.i
  else:
    error(jx, "Expected " & c & " but got " & jx.data[jx.i] & " instead.")

proc parseSymbol*(jx: JsonyContext): string =
  ## Will read a symbol and return it.
  ## Used for numbers and booleans.
  jx.eatSpace()
  var j = jx.i
  while jx.i < jx.data.len:
    case jx.data[jx.i]
    of ',', '}', ']', whiteSpace:
      break
    else:
      discard
    inc jx.i
  return jx.data[j ..< jx.i]

proc parseHook*(jx: JsonyContext, v: var bool) =
  ## Will parse boolean true or false.
  when nimvm:
    case jx.parseSymbol()
    of "true":
      v = true
    of "false":
      v = false
    else:
      error(jx, "Boolean true or false expected.")
  else:
    # Its faster to do char by char scan:
    jx.eatSpace()
    if jx.i + 3 < jx.data.len and jx.data[jx.i+0] == 't' and jx.data[jx.i+1] == 'r' and jx.data[jx.i+2] == 'u' and jx.data[jx.i+3] == 'e':
      jx.i += 4
      v = true
    elif jx.i + 4 < jx.data.len and jx.data[jx.i+0] == 'f' and jx.data[jx.i+1] == 'a' and jx.data[jx.i+2] == 'l' and jx.data[jx.i+3] == 's' and jx.data[jx.i+4] == 'e':
      jx.i += 5
      v = false
    else:
      error(jx, "Boolean true or false expected.")

proc parseHook*(jx: JsonyContext, v: var SomeUnsignedInt) =
  ## Will parse unsigned integers.
  when nimvm:
    v = type(v)(parseInt(jx.parseSymbol()))
  else:
    jx.eatSpace()
    var
      v2: uint64 = 0
      startI = jx.i
    while jx.i < jx.data.len and jx.data[jx.i] in {'0'..'9'}:
      v2 = v2 * 10 + (jx.data[jx.i].ord - '0'.ord).uint64
      inc jx.i
    if startI == jx.i:
      error(jx, "Number expected.")
    v = type(v)(v2)

proc parseHook*(jx: JsonyContext, v: var SomeSignedInt) =
  ## Will parse signed integers.
  when nimvm:
    v = type(v)(parseInt(jx.parseSymbol()))
  else:
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == '+':
      inc jx.i
    if jx.i < jx.data.len and jx.data[jx.i] == '-':
      var v2: uint64
      inc jx.i
      jx.parseHook(v2)
      v = -type(v)(v2)
    else:
      var v2: uint64
      jx.parseHook(v2)
      try:
        v = type(v)(v2)
      except:
        error(jx, "Number type to small to contain the number.")

proc parseHook*(jx: JsonyContext, v: var SomeFloat) =
  ## Will parse float32 and float64.
  var f: float
  jx.eatSpace()
  let chars = parseutils.parseFloat(jx.data, f, jx.i)
  if chars == 0:
    error(jx, "Failed to parse a float.")
  jx.i += chars
  v = f

proc parseStringSlow(jx: JsonyContext, v: var string) =
  while jx.i < jx.data.len:
    let c = jx.data[jx.i]
    case c
    of '"':
      break
    of '\\':
      inc jx.i
      let c = jx.data[jx.i]
      case c
      of '"', '\\', '/': v.add(c)
      of 'b': v.add '\b'
      of 'f': v.add '\f'
      of 'n': v.add '\n'
      of 'r': v.add '\r'
      of 't': v.add '\t'
      of 'u':
        inc jx.i
        let u = parseHexInt(jx.data[jx.i ..< jx.i + 4])
        jx.i += 3
        v.add(Rune(u).toUTF8())
      else:
        v.add(c)
    else:
      v.add(c)
    inc jx.i
  jx.eatChar('"')

proc parseStringFast(jx: JsonyContext, v: var string) =
  # It appears to be faster to scan the string once, then allocate exact chars,
  # and then scan the string again populating it.
  var
    j = jx.i
    ll = 0
  while j < jx.data.len:
    let c = jx.data[j]
    case c
    of '"':
      break
    of '\\':
      inc j
      let c = jx.data[j]
      case c
      of 'u':
        inc j
        let u = parseHexInt(jx.data[j ..< j + 4])
        j += 3
        ll += Rune(u).toUTF8().len
      else:
        inc ll
    else:
      inc ll
    inc j

  if ll > 0:
    v = newString(ll)
    var
      at = 0
      ss = cast[ptr UncheckedArray[char]](v[0].addr)
    template add(ss: ptr UncheckedArray[char], c: char) =
      ss[at] = c
      inc at
    while jx.i < jx.data.len:
      let c = jx.data[jx.i]
      case c
      of '"':
        break
      of '\\':
        inc jx.i
        let c = jx.data[jx.i]
        case c
        of '"', '\\', '/': ss.add(c)
        of 'b': ss.add '\b'
        of 'f': ss.add '\f'
        of 'n': ss.add '\n'
        of 'r': ss.add '\r'
        of 't': ss.add '\t'
        of 'u':
          inc jx.i
          let u = parseHexInt(jx.data[jx.i ..< jx.i + 4])
          jx.i += 3
          for c in Rune(u).toUTF8():
            ss.add(c)
        else:
          ss.add(c)
      else:
        ss.add(c)
      inc jx.i

  jx.eatChar('"')

proc parseHook*(jx: JsonyContext, v: var string) =
  ## Parse string.
  jx.eatSpace()
  if jx.i + 3 < jx.data.len and jx.data[jx.i+0] == 'n' and jx.data[jx.i+1] == 'u' and jx.data[jx.i+2] == 'l' and jx.data[jx.i+3] == 'l':
    jx.i += 4
    return
  jx.eatChar('"')

  when nimvm:
    jx.parseStringSlow(v)
  else:
    when defined(js):
      jx.parseStringSlow(v)
    else:
      jx.parseStringFast(v)

proc parseHook*(jx: JsonyContext, v: var char) =
  var str: string
  jx.parseHook(str)
  if str.len != 1:
    error(jx, "String can't fit into a char.")
  v = str[0]

proc parseHook*[T](jx: JsonyContext, v: var seq[T]) =
  ## Parse seq.
  jx.eatChar('[')
  while jx.i < jx.data.len:
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == ']':
      break
    var element: T
    jx.parseHook(element)
    v.add(element)
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == ',':
      inc jx.i
    else:
      break
  jx.eatChar(']')

proc parseHook*[T: array](jx: JsonyContext, v: var T) =
  jx.eatSpace()
  jx.eatChar('[')
  for value in v.mitems:
    jx.eatSpace()
    jx.parseHook(value)
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == ',':
      inc jx.i
  jx.eatChar(']')

proc parseHook*[T: not object](jx: JsonyContext, v: var ref T) =
  jx.eatSpace()
  if jx.i + 3 < jx.data.len and jx.data[jx.i+0] == 'n' and jx.data[jx.i+1] == 'u' and jx.data[jx.i+2] == 'l' and jx.data[jx.i+3] == 'l':
    jx.i += 4
    return
  new(v)
  jx.parseHook(v[])

proc skipValue(jx: JsonyContext) =
  ## Used to skip values of extra fields.
  jx.eatSpace()
  if jx.i < jx.data.len and jx.data[jx.i] == '{':
    jx.eatChar('{')
    while jx.i < jx.data.len:
      jx.eatSpace()
      if jx.i < jx.data.len and jx.data[jx.i] == '}':
        break
      jx.skipValue()
      jx.eatChar(':')
      jx.skipValue()
      jx.eatSpace()
      if jx.i < jx.data.len and jx.data[jx.i] == ',':
        inc jx.i
    jx.eatChar('}')
  elif jx.i < jx.data.len and jx.data[jx.i] == '[':
    jx.eatChar('[')
    while jx.i < jx.data.len:
      jx.eatSpace()
      if jx.i < jx.data.len and jx.data[jx.i] == ']':
        break
      jx.skipValue()
      jx.eatSpace()
      if jx.i < jx.data.len and jx.data[jx.i] == ',':
        inc jx.i
    jx.eatChar(']')
  elif jx.i < jx.data.len and jx.data[jx.i] == '"':
    var str: string
    jx.parseHook(str)
  else:
    discard jx.parseSymbol()

proc snakeCaseDynamic(s: string): string =
  if s.len == 0:
    return
  var prevCap = false
  for i, c in s:
    if c in {'A'..'Z'}:
      if result.len > 0 and result[result.len-1] != '_' and not prevCap:
        result.add '_'
      prevCap = true
      result.add c.toLowerAscii()
    else:
      prevCap = false
      result.add c

template snakeCase(s: string): string =
  const k = snakeCaseDynamic(s)
  k

proc parseObject[T](jx: JsonyContext, v: var T) =
  jx.eatChar('{')
  while jx.i < jx.data.len:
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == '}':
      break
    var key: string
    jx.parseHook(key)
    jx.eatChar(':')
    when compiles(renameHook(v, key)):
      renameHook(v, key)
    block all:
      for k, v in v.fieldPairs:
        if k == key or snakeCase(k) == key:
          var v2: type(v)
          jx.parseHook(v2)
          v = v2
          break all
      jx.skipValue()
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == ',':
      inc jx.i
    else:
      break

proc parseHook*[T: tuple](jx: JsonyContext, v: var T) =
  jx.eatSpace()
  when T.isNamedTuple():
    if jx.i < jx.data.len and jx.data[jx.i] == '{':
      jx.parseObject(v)
      return
  jx.eatChar('[')
  for name, value in v.fieldPairs:
    jx.eatSpace()
    jx.parseHook(value)
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == ',':
      inc jx.i
  jx.eatChar(']')

proc parseHook*[T: enum](jx: JsonyContext, v: var T) =
  jx.eatSpace()
  var strV: string
  if jx.i < jx.data.len and jx.data[jx.i] == '"':
    jx.parseHook(strV)
    when compiles(enumHook(strV, v)):
      enumHook(strV, v)
    else:
      try:
        v = parseEnum[T](strV)
      except:
        error(jx, "Can't parse enum.")
  else:
    try:
      strV = jx.parseSymbol()
      v = T(parseInt(strV))
    except:
      error(jx, "Can't parse enum.")

proc parseHook*[T: object|ref object](jx: JsonyContext, v: var T) =
  ## Parse an object or ref object.
  jx.eatSpace()
  if jx.i + 3 < jx.data.len and jx.data[jx.i+0] == 'n' and jx.data[jx.i+1] == 'u' and jx.data[jx.i+2] == 'l' and jx.data[jx.i+3] == 'l':
    jx.i += 4
    return
  jx.eatChar('{')
  when not v.isObjectVariant:
    when compiles(newHook(v)):
      newHook(v)
    elif compiles(new(v)):
      new(v)
  else:
    # Look for the discriminatorFieldName
    jx.eatSpace()
    var saveI = jx.i
    while jx.i < jx.data.len:
      var key: string
      jx.parseHook(key)
      jx.eatChar(':')
      when compiles(renameHook(v, key)):
        renameHook(v, key)
      if key == v.discriminatorFieldName:
        var discriminator: type(v.discriminatorField)
        jx.parseHook(discriminator)
        new(v, discriminator)
        when compiles(newHook(v)):
          newHook(v)
        break
      jx.skipValue()
      if jx.i < jx.data.len and jx.data[jx.i] == '}':
        error(jx, "No discriminator field.")
      jx.eatChar(',')
    jx.i = saveI
  while jx.i < jx.data.len:
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == '}':
      break
    var key: string
    jx.parseHook(key)
    jx.eatChar(':')
    when compiles(renameHook(v, key)):
      renameHook(v, key)
    block all:
      for k, v in v.fieldPairs:
        if k == key or snakeCase(k) == key:
          var v2: type(v)
          jx.parseHook(v2)
          v = v2
          break all
      jx.skipValue()
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == ',':
      inc jx.i
    else:
      break
  when compiles(postHook(v)):
    postHook(v)
  jx.eatChar('}')

proc parseHook*[T](jx: JsonyContext, v: var Option[T]) =
  ## Parse an Option.
  jx.eatSpace()
  if jx.i + 3 < jx.data.len and jx.data[jx.i+0] == 'n' and jx.data[jx.i+1] == 'u' and jx.data[jx.i+2] == 'l' and jx.data[jx.i+3] == 'l':
    jx.i += 4
    return
  var e: T
  jx.parseHook(e)
  v = some(e)

proc parseHook*[T](jx: JsonyContext, v: var SomeTable[string, T]) =
  ## Parse an object.
  when compiles(new(v)):
    new(v)
  jx.eatChar('{')
  while jx.i < jx.data.len:
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == '}':
      break
    var key: string
    jx.parseHook(key)
    jx.eatChar(':')
    var element: T
    jx.parseHook(element)
    v[key] = element
    if jx.i < jx.data.len and jx.data[jx.i] == ',':
      inc jx.i
    else:
      break
  jx.eatChar('}')

proc parseHook*[T](jx: JsonyContext, v: var (SomeSet[T]|set[T])) =
  ## Parses `HashSet`, `OrderedSet`, or a built-in `set` type.
  jx.eatSpace()
  jx.eatChar('[')
  while true:
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == ']':
      break
    var e: T
    jx.parseHook(e)
    v.incl(e)
    jx.eatSpace()
    if jx.i < jx.data.len and jx.data[jx.i] == ',':
      inc jx.i
  jx.eatChar(']')

proc parseHook*(jx: JsonyContext, v: var JsonNode) =
  ## Parses a regular json node.
  jx.eatSpace()
  if jx.i < jx.data.len and jx.data[jx.i] == '{':
    v = newJObject()
    jx.eatChar('{')
    while jx.i < jx.data.len:
      jx.eatSpace()
      if jx.i < jx.data.len and jx.data[jx.i] == '}':
        break
      var k: string
      jx.parseHook(k)
      jx.eatChar(':')
      var e: JsonNode
      jx.parseHook(e)
      v[k] = e
      jx.eatSpace()
      if jx.i < jx.data.len and jx.data[jx.i] == ',':
        inc jx.i
    jx.eatChar('}')
  elif jx.i < jx.data.len and jx.data[jx.i] == '[':
    v = newJArray()
    jx.eatChar('[')
    while jx.i < jx.data.len:
      jx.eatSpace()
      if jx.i < jx.data.len and jx.data[jx.i] == ']':
        break
      var e: JsonNode
      jx.parseHook(e)
      v.add(e)
      jx.eatSpace()
      if jx.i < jx.data.len and jx.data[jx.i] == ',':
        inc jx.i
    jx.eatChar(']')
  elif jx.i < jx.data.len and jx.data[jx.i] == '"':
    var str: string
    jx.parseHook(str)
    v = newJString(str)
  else:
    var data = jx.parseSymbol()
    if data == "null":
      v = newJNull()
    elif data == "true":
      v = newJBool(true)
    elif data == "false":
      v = newJBool(false)
    elif data.len > 0 and data[0] in {'0'..'9', '-', '+'}:
      try:
        v = newJInt(parseInt(data))
      except ValueError:
        try:
          v = newJFloat(parseFloat(data))
        except ValueError:
          error(jx, "Invalid number.")
    else:
      error(jx, "Unexpected.")

proc parseHook*[T: distinct](jx: JsonyContext, v: var T) =
  var x: T.distinctBase
  jx.parseHook(x)
  v = cast[T](x)

proc fromJson*[T](s: string, x: typedesc[T]): T =
  ## Takes json and outputs the object it represents.
  ## * Extra json fields are ignored.
  ## * Missing json fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.
  var jx = JsonyContext(data: s)
  jx.parseHook(result)

proc fromJson*(s: string): JsonNode =
  ## Takes json parses it into `JsonNode`jx.data.
  var jx = JsonyContext(data: s)
  jx.parseHook(result)



proc dumpHook*(jx: JsonyContext, v: bool)
proc dumpHook*(jx: JsonyContext, v: uint|uint8|uint16|uint32|uint64)
proc dumpHook*(jx: JsonyContext, v: int|int8|int16|int32|int64)
proc dumpHook*(jx: JsonyContext, v: SomeFloat)
proc dumpHook*(jx: JsonyContext, v: string)
proc dumpHook*(jx: JsonyContext, v: char)
proc dumpHook*(jx: JsonyContext, v: tuple)
proc dumpHook*(jx: JsonyContext, v: enum)
type t[T] = tuple[a:string, b:T]
proc dumpHook*[N, T](jx: JsonyContext, v: array[N, t[T]])
proc dumpHook*[N, T](jx: JsonyContext, v: array[N, T])
proc dumpHook*[T](jx: JsonyContext, v: seq[T])
proc dumpHook*(jx: JsonyContext, v: object)
proc dumpHook*(jx: JsonyContext, v: ref)
proc dumpHook*[T: distinct](jx: JsonyContext, v: T)

proc dumpHook*[T: distinct](jx: JsonyContext, v: T) =
  var x = cast[T.distinctBase](v)
  jx.dumpHook(x)

proc dumpHook*(jx: JsonyContext, v: bool) =
  if v:
    jx.data.add "true"
  else:
    jx.data.add "false"

const lookup = block:
  ## Generate 00, 01, 02 ... 99 pairs.
  var s = ""
  for i in 0 ..< 100:
    if ($i).len == 1:
      s.add("0")
    s.add($i)
  s

proc dumpNumberSlow(jx: JsonyContext, v: uint|uint8|uint16|uint32|uint64) =
  jx.data.add $v.uint64

proc dumpNumberFast(jx: JsonyContext, v: uint|uint8|uint16|uint32|uint64) =
  # Its faster to not allocate a string for a number,
  # but to write it out the digits directly.
  if v == 0:
    jx.data.add '0'
    return
  # Max size of a uin64 number is 20 digits.
  var digits: array[20, char]
  var v = v
  var p = 0
  while v != 0:
    # Its faster to look up 2 digits at a time, less int divisions.
    let idx = v mod 100
    digits[p] = lookup[idx*2+1]
    inc p
    digits[p] = lookup[idx*2]
    inc p
    v = v div 100
  var at = jx.data.len
  if digits[p-1] == '0':
    dec p
  jx.data.setLen(jx.data.len + p)
  dec p
  while p >= 0:
    jx.data[at] = digits[p]
    dec p
    inc at

proc dumpHook*(jx: JsonyContext, v: uint|uint8|uint16|uint32|uint64) =
  when nimvm:
    jx.dumpNumberSlow(v)
  else:
    when defined(js):
      jx.dumpNumberSlow(v)
    else:
      jx.dumpNumberFast(v)

proc dumpHook*(jx: JsonyContext, v: int|int8|int16|int32|int64) =
  if v < 0:
    jx.data.add '-'
    jx.dumpHook( 0.uint64 - v.uint64)
  else:
    jx.dumpHook(v.uint64)

proc dumpHook*(jx: JsonyContext, v: SomeFloat) =
  jx.data.add $v

proc dumpStrSlow(jx: JsonyContext, v: string) =
  jx.data.add '"'
  for c in v:
    case c:
    of '\\': jx.data.add r"\\"
    of '\b': jx.data.add r"\b"
    of '\f': jx.data.add r"\f"
    of '\n': jx.data.add r"\n"
    of '\r': jx.data.add r"\r"
    of '\t': jx.data.add r"\t"
    of '"': jx.data.add r"\"""
    else:
      jx.data.add c
  jx.data.add '"'

proc dumpStrFast(jx: JsonyContext, v: string) =
  # Its faster to grow the string only once.
  # Then fill the string with pointers.
  # Then cap it off to right length.
  var at = jx.data.len
  jx.data.setLen(jx.data.len + v.len*2+2)

  var ss = cast[ptr UncheckedArray[char]](jx.data[0].addr)
  template add(ss: ptr UncheckedArray[char], c: char) =
    ss[at] = c
    inc at
  template add(ss: ptr UncheckedArray[char], c1, c2: char) =
    ss[at] = c1
    inc at
    ss[at] = c2
    inc at

  ss.add '"'
  for c in v:
    case c:
    of '\\': ss.add '\\', '\\'
    of '\b': ss.add '\\', 'b'
    of '\f': ss.add '\\', 'f'
    of '\n': ss.add '\\', 'n'
    of '\r': ss.add '\\', 'r'
    of '\t': ss.add '\\', 't'
    of '"': ss.add '\\', '"'
    else:
      ss.add c
  ss.add '"'
  jx.data.setLen(at)

proc dumpHook*(jx: JsonyContext, v: string) =
  when nimvm:
    jx.dumpStrSlow(v)
  else:
    when defined(js):
      jx.dumpStrSlow(v)
    else:
      jx.dumpStrFast(v)

template dumpKey(jx: JsonyContext, v: string) =
  const v2 = v.toJson() & ":"
  jx.data.add v2

proc dumpHook*(jx: JsonyContext, v: char) =
  jx.data.add '"'
  jx.data.add v
  jx.data.add '"'

proc dumpHook*(jx: JsonyContext, v: tuple) =
  jx.data.add '['
  var i = 0
  for _, e in v.fieldPairs:
    if i > 0:
      jx.data.add ','
    jx.dumpHook(e)
    inc i
  jx.data.add ']'

proc dumpHook*(jx: JsonyContext, v: enum) =
  jx.dumpHook($v)

proc dumpHook*[N, T](jx: JsonyContext, v: array[N, T]) =
  jx.data.add '['
  var i = 0
  for e in v:
    if i != 0:
      jx.data.add ','
    jx.dumpHook(e)
    inc i
  jx.data.add ']'

proc dumpHook*[T](jx: JsonyContext, v: seq[T]) =
  jx.data.add '['
  for i, e in v:
    if i != 0:
      jx.data.add ','
    jx.dumpHook(e)
  jx.data.add ']'

proc dumpHook*[T](jx: JsonyContext, v: Option[T]) =
  if v.isNone:
    jx.data.add "null"
  else:
    jx.dumpHook(v.get())

proc dumpHook*(jx: JsonyContext, v: object) =
  jx.data.add '{'
  var i = 0
  when compiles(for k, e in v.pairs: discard):
    # Tables and table like objects.
    for k, e in v.pairs:
      if i > 0:
        jx.data.add ','
      jx.dumpHook(k)
      jx.data.add ':'
      jx.dumpHook(e)
      inc i
  else:
    # Normal objects.
    for k, e in v.fieldPairs:
      if i > 0:
        jx.data.add ','
      jx.dumpKey(k)
      jx.dumpHook(e)
      inc i
  jx.data.add '}'

proc dumpHook*[N, T](jx: JsonyContext, v: array[N, t[T]]) =
  jx.data.add '{'
  var i = 0
  # Normal objects.
  for (k, e) in v:
    if i > 0:
      jx.data.add ','
    jx.dumpHook(k)
    jx.data.add ':'
    jx.dumpHook(e)
    inc i
  jx.data.add '}'

proc dumpHook*(jx: JsonyContext, v: ref) =
  if v == nil:
    jx.data.add "null"
  else:
    jx.dumpHook(v[])

proc dumpHook*[T](jx: JsonyContext, v: SomeSet[T]|set[T]) =
  jx.data.add '['
  var i = 0
  for e in v:
    if i != 0:
      jx.data.add ','
    jx.dumpHook(e)
    inc i
  jx.data.add ']'

proc dumpHook*(jx: JsonyContext, v: JsonNode) =
  ## Dumps a regular json node.
  if v == nil:
    jx.data.add "null"
  else:
    case v.kind:
    of JObject:
      jx.data.add '{'
      var i = 0
      for k, e in v.pairs:
        if i != 0:
          jx.data.add ","
        jx.dumpHook(k)
        jx.data.add ':'
        jx.dumpHook(e)
        inc i
      jx.data.add '}'
    of JArray:
      jx.data.add '['
      var i = 0
      for e in v:
        if i != 0:
          jx.data.add ","
        jx.dumpHook(e)
        inc i
      jx.data.add ']'
    of JNull:
      jx.data.add "null"
    of JInt:
      jx.dumpHook(v.getInt)
    of JFloat:
      jx.dumpHook(v.getFloat)
    of JString:
      jx.dumpHook(v.getStr)
    of JBool:
      jx.dumpHook(v.getBool)

proc toJson*[T](v: T): string =
  let jx = JsonyContext()
  jx.dumpHook(v)
  jx.data

template toStaticJson*(v: untyped): static[string] =
  ## This will turn v into json at compile time and return the json string.
  const s = v.toJson()
  s

# A compiler bug prevents this from working. Otherwise toStaticJson and toJson
# can be same thing.
# TODO: Figure out the compiler bug.
# proc toJsonDynamic*[T](v: T): string =
#   dumpHook(result, v)
# template toJson*[T](v: static[T]): string =
#   ## This will turn v into json at compile time and return the json string.
#   const s = v.toJsonDynamic()
#   s


when defined(release):
  {.pop.}
