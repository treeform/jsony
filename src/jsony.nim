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

proc parseHook*[T](ctx: JsonyContext, v: var seq[T])
proc parseHook*[T: enum](ctx: JsonyContext, v: var T)
proc parseHook*[T: object|ref object](ctx: JsonyContext, v: var T)
proc parseHook*[T](ctx: JsonyContext, v: var SomeTable[string, T])
proc parseHook*[T](ctx: JsonyContext, v: var (SomeSet[T]|set[T]))
proc parseHook*[T: tuple](ctx: JsonyContext, v: var T)
proc parseHook*[T: array](ctx: JsonyContext, v: var T)
proc parseHook*[T: not object](ctx: JsonyContext, v: var ref T)
proc parseHook*(ctx: JsonyContext, v: var JsonNode)
proc parseHook*(ctx: JsonyContext, v: var char)
proc parseHook*[T: distinct](ctx: JsonyContext, v: var T)

template error(ctx: JsonyContext, msg: string) =
  ## Shortcut to raise an exception.
  raise newException(JsonError, msg & " At offset: " & $ctx.i)

template eatSpace*(ctx: JsonyContext) =
  ## Will consume whitespace.
  while ctx.i < ctx.data.len:
    let c = ctx.data[ctx.i]
    if c notin whiteSpace:
      break
    inc ctx.i

template eatChar*(ctx: JsonyContext, c: char) =
  ## Will consume space before and then the character `c`.
  ## Will raise an exception if `c` is not found.
  ctx.eatSpace()
  if ctx.i >= ctx.data.len:
    error(ctx, "Expected " & c & " but end reached.")
  if ctx.data[ctx.i] == c:
    inc ctx.i
  else:
    error(ctx, "Expected " & c & " but got " & ctx.data[ctx.i] & " instead.")

proc parseSymbol*(ctx: JsonyContext): string =
  ## Will read a symbol and return it.
  ## Used for numbers and booleans.
  ctx.eatSpace()
  var j = ctx.i
  while ctx.i < ctx.data.len:
    case ctx.data[ctx.i]
    of ',', '}', ']', whiteSpace:
      break
    else:
      discard
    inc ctx.i
  return ctx.data[j ..< ctx.i]

proc parseHook*(ctx: JsonyContext, v: var bool) =
  ## Will parse boolean true or false.
  when nimvm:
    case ctx.parseSymbol()
    of "true":
      v = true
    of "false":
      v = false
    else:
      error(ctx, "Boolean true or false expected.")
  else:
    # Its faster to do char by char scan:
    ctx.eatSpace()
    if ctx.i + 3 < ctx.data.len and ctx.data[ctx.i+0] == 't' and ctx.data[ctx.i+1] == 'r' and ctx.data[ctx.i+2] == 'u' and ctx.data[ctx.i+3] == 'e':
      ctx.i += 4
      v = true
    elif ctx.i + 4 < ctx.data.len and ctx.data[ctx.i+0] == 'f' and ctx.data[ctx.i+1] == 'a' and ctx.data[ctx.i+2] == 'l' and ctx.data[ctx.i+3] == 's' and ctx.data[ctx.i+4] == 'e':
      ctx.i += 5
      v = false
    else:
      error(ctx, "Boolean true or false expected.")

proc parseHook*(ctx: JsonyContext, v: var SomeUnsignedInt) =
  ## Will parse unsigned integers.
  when nimvm:
    v = type(v)(parseInt(ctx.parseSymbol()))
  else:
    ctx.eatSpace()
    var
      v2: uint64 = 0
      startI = ctx.i
    while ctx.i < ctx.data.len and ctx.data[ctx.i] in {'0'..'9'}:
      v2 = v2 * 10 + (ctx.data[ctx.i].ord - '0'.ord).uint64
      inc ctx.i
    if startI == ctx.i:
      error(ctx, "Number expected.")
    v = type(v)(v2)

proc parseHook*(ctx: JsonyContext, v: var SomeSignedInt) =
  ## Will parse signed integers.
  when nimvm:
    v = type(v)(parseInt(ctx.parseSymbol()))
  else:
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == '+':
      inc ctx.i
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == '-':
      var v2: uint64
      inc ctx.i
      ctx.parseHook(v2)
      v = -type(v)(v2)
    else:
      var v2: uint64
      ctx.parseHook(v2)
      try:
        v = type(v)(v2)
      except:
        error(ctx, "Number type to small to contain the number.")

proc parseHook*(ctx: JsonyContext, v: var SomeFloat) =
  ## Will parse float32 and float64.
  var f: float
  ctx.eatSpace()
  let chars = parseutils.parseFloat(ctx.data, f, ctx.i)
  if chars == 0:
    error(ctx, "Failed to parse a float.")
  ctx.i += chars
  v = f

proc parseStringSlow(ctx: JsonyContext, v: var string) =
  while ctx.i < ctx.data.len:
    let c = ctx.data[ctx.i]
    case c
    of '"':
      break
    of '\\':
      inc ctx.i
      let c = ctx.data[ctx.i]
      case c
      of '"', '\\', '/': v.add(c)
      of 'b': v.add '\b'
      of 'f': v.add '\f'
      of 'n': v.add '\n'
      of 'r': v.add '\r'
      of 't': v.add '\t'
      of 'u':
        inc ctx.i
        let u = parseHexInt(ctx.data[ctx.i ..< ctx.i + 4])
        ctx.i += 3
        v.add(Rune(u).toUTF8())
      else:
        v.add(c)
    else:
      v.add(c)
    inc ctx.i
  ctx.eatChar('"')

proc parseStringFast(ctx: JsonyContext, v: var string) =
  # It appears to be faster to scan the string once, then allocate exact chars,
  # and then scan the string again populating it.
  var
    j = ctx.i
    ll = 0
  while j < ctx.data.len:
    let c = ctx.data[j]
    case c
    of '"':
      break
    of '\\':
      inc j
      let c = ctx.data[j]
      case c
      of 'u':
        inc j
        let u = parseHexInt(ctx.data[j ..< j + 4])
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
    while ctx.i < ctx.data.len:
      let c = ctx.data[ctx.i]
      case c
      of '"':
        break
      of '\\':
        inc ctx.i
        let c = ctx.data[ctx.i]
        case c
        of '"', '\\', '/': ss.add(c)
        of 'b': ss.add '\b'
        of 'f': ss.add '\f'
        of 'n': ss.add '\n'
        of 'r': ss.add '\r'
        of 't': ss.add '\t'
        of 'u':
          inc ctx.i
          let u = parseHexInt(ctx.data[ctx.i ..< ctx.i + 4])
          ctx.i += 3
          for c in Rune(u).toUTF8():
            ss.add(c)
        else:
          ss.add(c)
      else:
        ss.add(c)
      inc ctx.i

  ctx.eatChar('"')

proc parseHook*(ctx: JsonyContext, v: var string) =
  ## Parse string.
  ctx.eatSpace()
  if ctx.i + 3 < ctx.data.len and ctx.data[ctx.i+0] == 'n' and ctx.data[ctx.i+1] == 'u' and ctx.data[ctx.i+2] == 'l' and ctx.data[ctx.i+3] == 'l':
    ctx.i += 4
    return
  ctx.eatChar('"')

  when nimvm:
    ctx.parseStringSlow(v)
  else:
    when defined(js):
      ctx.parseStringSlow(v)
    else:
      ctx.parseStringFast(v)

proc parseHook*(ctx: JsonyContext, v: var char) =
  var str: string
  ctx.parseHook(str)
  if str.len != 1:
    error(ctx, "String can't fit into a char.")
  v = str[0]

proc parseHook*[T](ctx: JsonyContext, v: var seq[T]) =
  ## Parse seq.
  ctx.eatChar('[')
  while ctx.i < ctx.data.len:
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ']':
      break
    var element: T
    ctx.parseHook(element)
    v.add(element)
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
      inc ctx.i
    else:
      break
  ctx.eatChar(']')

proc parseHook*[T: array](ctx: JsonyContext, v: var T) =
  ctx.eatSpace()
  ctx.eatChar('[')
  for value in v.mitems:
    ctx.eatSpace()
    ctx.parseHook(value)
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
      inc ctx.i
  ctx.eatChar(']')

proc parseHook*[T: not object](ctx: JsonyContext, v: var ref T) =
  ctx.eatSpace()
  if ctx.i + 3 < ctx.data.len and ctx.data[ctx.i+0] == 'n' and ctx.data[ctx.i+1] == 'u' and ctx.data[ctx.i+2] == 'l' and ctx.data[ctx.i+3] == 'l':
    ctx.i += 4
    return
  new(v)
  ctx.parseHook(v[])

proc skipValue(ctx: JsonyContext) =
  ## Used to skip values of extra fields.
  ctx.eatSpace()
  if ctx.i < ctx.data.len and ctx.data[ctx.i] == '{':
    ctx.eatChar('{')
    while ctx.i < ctx.data.len:
      ctx.eatSpace()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == '}':
        break
      ctx.skipValue()
      ctx.eatChar(':')
      ctx.skipValue()
      ctx.eatSpace()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
        inc ctx.i
    ctx.eatChar('}')
  elif ctx.i < ctx.data.len and ctx.data[ctx.i] == '[':
    ctx.eatChar('[')
    while ctx.i < ctx.data.len:
      ctx.eatSpace()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == ']':
        break
      ctx.skipValue()
      ctx.eatSpace()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
        inc ctx.i
    ctx.eatChar(']')
  elif ctx.i < ctx.data.len and ctx.data[ctx.i] == '"':
    var str: string
    ctx.parseHook(str)
  else:
    discard ctx.parseSymbol()

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

proc parseObject[T](ctx: JsonyContext, v: var T) =
  ctx.eatChar('{')
  while ctx.i < ctx.data.len:
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == '}':
      break
    var key: string
    ctx.parseHook(key)
    ctx.eatChar(':')
    when compiles(renameHook(v, key)):
      renameHook(v, key)
    block all:
      for k, v in v.fieldPairs:
        if k == key or snakeCase(k) == key:
          var v2: type(v)
          ctx.parseHook(v2)
          v = v2
          break all
      ctx.skipValue()
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
      inc ctx.i
    else:
      break

proc parseHook*[T: tuple](ctx: JsonyContext, v: var T) =
  ctx.eatSpace()
  when T.isNamedTuple():
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == '{':
      ctx.parseObject(v)
      return
  ctx.eatChar('[')
  for name, value in v.fieldPairs:
    ctx.eatSpace()
    ctx.parseHook(value)
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
      inc ctx.i
  ctx.eatChar(']')

proc parseHook*[T: enum](ctx: JsonyContext, v: var T) =
  ctx.eatSpace()
  var strV: string
  if ctx.i < ctx.data.len and ctx.data[ctx.i] == '"':
    ctx.parseHook(strV)
    when compiles(enumHook(strV, v)):
      enumHook(strV, v)
    else:
      try:
        v = parseEnum[T](strV)
      except:
        error(ctx, "Can't parse enum.")
  else:
    try:
      strV = ctx.parseSymbol()
      v = T(parseInt(strV))
    except:
      error(ctx, "Can't parse enum.")

proc parseHook*[T: object|ref object](ctx: JsonyContext, v: var T) =
  ## Parse an object or ref object.
  ctx.eatSpace()
  if ctx.i + 3 < ctx.data.len and ctx.data[ctx.i+0] == 'n' and ctx.data[ctx.i+1] == 'u' and ctx.data[ctx.i+2] == 'l' and ctx.data[ctx.i+3] == 'l':
    ctx.i += 4
    return
  ctx.eatChar('{')
  when not v.isObjectVariant:
    when compiles(newHook(v)):
      newHook(v)
    elif compiles(new(v)):
      new(v)
  else:
    # Look for the discriminatorFieldName
    ctx.eatSpace()
    var saveI = ctx.i
    while ctx.i < ctx.data.len:
      var key: string
      ctx.parseHook(key)
      ctx.eatChar(':')
      when compiles(renameHook(v, key)):
        renameHook(v, key)
      if key == v.discriminatorFieldName:
        var discriminator: type(v.discriminatorField)
        ctx.parseHook(discriminator)
        new(v, discriminator)
        when compiles(newHook(v)):
          newHook(v)
        break
      ctx.skipValue()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == '}':
        error(ctx, "No discriminator field.")
      ctx.eatChar(',')
    ctx.i = saveI
  while ctx.i < ctx.data.len:
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == '}':
      break
    var key: string
    ctx.parseHook(key)
    ctx.eatChar(':')
    when compiles(renameHook(v, key)):
      renameHook(v, key)
    block all:
      for k, v in v.fieldPairs:
        if k == key or snakeCase(k) == key:
          var v2: type(v)
          ctx.parseHook(v2)
          v = v2
          break all
      ctx.skipValue()
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
      inc ctx.i
    else:
      break
  when compiles(postHook(v)):
    postHook(v)
  ctx.eatChar('}')

proc parseHook*[T](ctx: JsonyContext, v: var Option[T]) =
  ## Parse an Option.
  ctx.eatSpace()
  if ctx.i + 3 < ctx.data.len and ctx.data[ctx.i+0] == 'n' and ctx.data[ctx.i+1] == 'u' and ctx.data[ctx.i+2] == 'l' and ctx.data[ctx.i+3] == 'l':
    ctx.i += 4
    return
  var e: T
  ctx.parseHook(e)
  v = some(e)

proc parseHook*[T](ctx: JsonyContext, v: var SomeTable[string, T]) =
  ## Parse an object.
  when compiles(new(v)):
    new(v)
  ctx.eatChar('{')
  while ctx.i < ctx.data.len:
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == '}':
      break
    var key: string
    ctx.parseHook(key)
    ctx.eatChar(':')
    var element: T
    ctx.parseHook(element)
    v[key] = element
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
      inc ctx.i
    else:
      break
  ctx.eatChar('}')

proc parseHook*[T](ctx: JsonyContext, v: var (SomeSet[T]|set[T])) =
  ## Parses `HashSet`, `OrderedSet`, or a built-in `set` type.
  ctx.eatSpace()
  ctx.eatChar('[')
  while true:
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ']':
      break
    var e: T
    ctx.parseHook(e)
    v.incl(e)
    ctx.eatSpace()
    if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
      inc ctx.i
  ctx.eatChar(']')

proc parseHook*(ctx: JsonyContext, v: var JsonNode) =
  ## Parses a regular json node.
  ctx.eatSpace()
  if ctx.i < ctx.data.len and ctx.data[ctx.i] == '{':
    v = newJObject()
    ctx.eatChar('{')
    while ctx.i < ctx.data.len:
      ctx.eatSpace()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == '}':
        break
      var k: string
      ctx.parseHook(k)
      ctx.eatChar(':')
      var e: JsonNode
      ctx.parseHook(e)
      v[k] = e
      ctx.eatSpace()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
        inc ctx.i
    ctx.eatChar('}')
  elif ctx.i < ctx.data.len and ctx.data[ctx.i] == '[':
    v = newJArray()
    ctx.eatChar('[')
    while ctx.i < ctx.data.len:
      ctx.eatSpace()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == ']':
        break
      var e: JsonNode
      ctx.parseHook(e)
      v.add(e)
      ctx.eatSpace()
      if ctx.i < ctx.data.len and ctx.data[ctx.i] == ',':
        inc ctx.i
    ctx.eatChar(']')
  elif ctx.i < ctx.data.len and ctx.data[ctx.i] == '"':
    var str: string
    ctx.parseHook(str)
    v = newJString(str)
  else:
    var data = ctx.parseSymbol()
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
          error(ctx, "Invalid number.")
    else:
      error(ctx, "Unexpected.")

proc parseHook*[T: distinct](ctx: JsonyContext, v: var T) =
  var x: T.distinctBase
  ctx.parseHook(x)
  v = cast[T](x)

proc fromJson*[T](s: string, x: typedesc[T]): T =
  ## Takes json and outputs the object it represents.
  ## * Extra json fields are ignored.
  ## * Missing json fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.
  var ctx = JsonyContext(data: s)
  ctx.parseHook(result)

proc fromJson*(s: string): JsonNode =
  ## Takes json parses it into `JsonNode`ctx.data.
  var ctx = JsonyContext(data: s)
  ctx.parseHook(result)



proc dumpHook*(s: var string, v: bool)
proc dumpHook*(s: var string, v: uint|uint8|uint16|uint32|uint64)
proc dumpHook*(s: var string, v: int|int8|int16|int32|int64)
proc dumpHook*(s: var string, v: SomeFloat)
proc dumpHook*(s: var string, v: string)
proc dumpHook*(s: var string, v: char)
proc dumpHook*(s: var string, v: tuple)
proc dumpHook*(s: var string, v: enum)
type t[T] = tuple[a:string, b:T]
proc dumpHook*[N, T](s: var string, v: array[N, t[T]])
proc dumpHook*[N, T](s: var string, v: array[N, T])
proc dumpHook*[T](s: var string, v: seq[T])
proc dumpHook*(s: var string, v: object)
proc dumpHook*(s: var string, v: ref)
proc dumpHook*[T: distinct](s: var string, v: T)

proc dumpHook*[T: distinct](s: var string, v: T) =
  var x = cast[T.distinctBase](v)
  s.dumpHook(x)

proc dumpHook*(s: var string, v: bool) =
  if v:
    s.add "true"
  else:
    s.add "false"

const lookup = block:
  ## Generate 00, 01, 02 ... 99 pairs.
  var s = ""
  for i in 0 ..< 100:
    if ($i).len == 1:
      s.add("0")
    s.add($i)
  s

proc dumpNumberSlow(s: var string, v: uint|uint8|uint16|uint32|uint64) =
  s.add $v.uint64

proc dumpNumberFast(s: var string, v: uint|uint8|uint16|uint32|uint64) =
  # Its faster to not allocate a string for a number,
  # but to write it out the digits directly.
  if v == 0:
    s.add '0'
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
  var at = s.len
  if digits[p-1] == '0':
    dec p
  s.setLen(s.len + p)
  dec p
  while p >= 0:
    s[at] = digits[p]
    dec p
    inc at

proc dumpHook*(s: var string, v: uint|uint8|uint16|uint32|uint64) =
  when nimvm:
    s.dumpNumberSlow(v)
  else:
    when defined(js):
      s.dumpNumberSlow(v)
    else:
      s.dumpNumberFast(v)

proc dumpHook*(s: var string, v: int|int8|int16|int32|int64) =
  if v < 0:
    s.add '-'
    dumpHook(s, 0.uint64 - v.uint64)
  else:
    dumpHook(s, v.uint64)

proc dumpHook*(s: var string, v: SomeFloat) =
  s.add $v

proc dumpStrSlow(s: var string, v: string) =
  s.add '"'
  for c in v:
    case c:
    of '\\': s.add r"\\"
    of '\b': s.add r"\b"
    of '\f': s.add r"\f"
    of '\n': s.add r"\n"
    of '\r': s.add r"\r"
    of '\t': s.add r"\t"
    of '"': s.add r"\"""
    else:
      s.add c
  s.add '"'

proc dumpStrFast(s: var string, v: string) =
  # Its faster to grow the string only once.
  # Then fill the string with pointers.
  # Then cap it off to right length.
  var at = s.len
  s.setLen(s.len + v.len*2+2)

  var ss = cast[ptr UncheckedArray[char]](s[0].addr)
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
  s.setLen(at)

proc dumpHook*(s: var string, v: string) =
  when nimvm:
    s.dumpStrSlow(v)
  else:
    when defined(js):
      s.dumpStrSlow(v)
    else:
      s.dumpStrFast(v)

template dumpKey(s: var string, v: string) =
  const v2 = v.toJson() & ":"
  s.add v2

proc dumpHook*(s: var string, v: char) =
  s.add '"'
  s.add v
  s.add '"'

proc dumpHook*(s: var string, v: tuple) =
  s.add '['
  var i = 0
  for _, e in v.fieldPairs:
    if i > 0:
      s.add ','
    s.dumpHook(e)
    inc i
  s.add ']'

proc dumpHook*(s: var string, v: enum) =
  s.dumpHook($v)

proc dumpHook*[N, T](s: var string, v: array[N, T]) =
  s.add '['
  var i = 0
  for e in v:
    if i != 0:
      s.add ','
    s.dumpHook(e)
    inc i
  s.add ']'

proc dumpHook*[T](s: var string, v: seq[T]) =
  s.add '['
  for i, e in v:
    if i != 0:
      s.add ','
    s.dumpHook(e)
  s.add ']'

proc dumpHook*[T](s: var string, v: Option[T]) =
  if v.isNone:
    s.add "null"
  else:
    s.dumpHook(v.get())

proc dumpHook*(s: var string, v: object) =
  s.add '{'
  var i = 0
  when compiles(for k, e in v.pairs: discard):
    # Tables and table like objects.
    for k, e in v.pairs:
      if i > 0:
        s.add ','
      s.dumpHook(k)
      s.add ':'
      s.dumpHook(e)
      inc i
  else:
    # Normal objects.
    for k, e in v.fieldPairs:
      if i > 0:
        s.add ','
      s.dumpKey(k)
      s.dumpHook(e)
      inc i
  s.add '}'

proc dumpHook*[N, T](s: var string, v: array[N, t[T]]) =
  s.add '{'
  var i = 0
  # Normal objects.
  for (k, e) in v:
    if i > 0:
      s.add ','
    s.dumpHook(k)
    s.add ':'
    s.dumpHook(e)
    inc i
  s.add '}'

proc dumpHook*(s: var string, v: ref) =
  if v == nil:
    s.add "null"
  else:
    s.dumpHook(v[])

proc dumpHook*[T](s: var string, v: SomeSet[T]|set[T]) =
  s.add '['
  var i = 0
  for e in v:
    if i != 0:
      s.add ','
    s.dumpHook(e)
    inc i
  s.add ']'

proc dumpHook*(s: var string, v: JsonNode) =
  ## Dumps a regular json node.
  if v == nil:
    s.add "null"
  else:
    case v.kind:
    of JObject:
      s.add '{'
      var i = 0
      for k, e in v.pairs:
        if i != 0:
          s.add ","
        s.dumpHook(k)
        s.add ':'
        s.dumpHook(e)
        inc i
      s.add '}'
    of JArray:
      s.add '['
      var i = 0
      for e in v:
        if i != 0:
          s.add ","
        s.dumpHook(e)
        inc i
      s.add ']'
    of JNull:
      s.add "null"
    of JInt:
      s.dumpHook(v.getInt)
    of JFloat:
      s.dumpHook(v.getFloat)
    of JString:
      s.dumpHook(v.getStr)
    of JBool:
      s.dumpHook(v.getBool)

proc toJson*[T](v: T): string =
  dumpHook(result, v)

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
