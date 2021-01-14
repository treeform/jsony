import jsony/objvar, strutils, tables, sets, unicode, json, options

type JsonError* = object of ValueError

const whiteSpace = {' ', '\n', '\t', '\r'}

when defined(release):
  {.push checks: off.}

type SomeTable*[K, V] = Table[K, V] | OrderedTable[K, V] |
  TableRef[K, V] | OrderedTableRef[K, V]

proc parseHook*[T](s: string, i: var int, v: var seq[T])
proc parseHook*[T: enum](s: string, i: var int, v: var T)
proc parseHook*[T: object|ref object](s: string, i: var int, v: var T)
proc parseHook*[T](s: string, i: var int, v: var SomeTable[string, T])
proc parseHook*[T](s: string, i: var int, v: var SomeSet[T])
proc parseHook*[T: tuple](s: string, i: var int, v: var T)
proc parseHook*[T: array](s: string, i: var int, v: var T)
proc parseHook*(s: string, i: var int, v: var JsonNode)
proc parseHook*(s: string, i: var int, v: var char)

template error(msg: string, i: int) =
  ## Shortcut to raise an exception.
  raise newException(JsonError, msg & " At offset: " & $i)

template eatSpace*(s: string, i: var int) =
  ## Will consume whitespace.
  while i < s.len:
    let c = s[i]
    if c notin whiteSpace:
      break
    inc i

template eatChar*(s: string, i: var int, c: char) =
  ## Will consume space before and then the character `c`.
  ## Will raise an exception if `c` is not found.
  eatSpace(s, i)
  if i >= s.len:
    error("Expected " & c & " but end reached.", i)
  if s[i] == c:
    inc i
  else:
    error("Expected " & c & ".", i)

proc parseSymbol*(s: string, i: var int): string =
  ## Will read a symbol and return it.
  ## Used for numbers and booleans.
  eatSpace(s, i)
  var j = i
  while i < s.len:
    case s[i]
    of ',', '}', ']', whiteSpace:
      break
    else:
      discard
    inc i
  return s[j ..< i]

proc parseHook*(s: string, i: var int, v: var bool) =
  ## Will parse boolean true or false.
  when nimvm:
    case parseSymbol(s, i)
    of "true":
      v = true
    of "false":
      v = false
    else:
      error("Boolean true or false expected.", i)
  else:
    # Its faster to do char by char scan:
    eatSpace(s, i)
    if i + 3 < s.len and s[i+0] == 't' and s[i+1] == 'r' and s[i+2] == 'u' and s[i+3] == 'e':
      i += 4
      v = true
    elif i + 4 < s.len and s[i+0] == 'f' and s[i+1] == 'a' and s[i+2] == 'l' and s[i+3] == 's' and s[i+4] == 'e':
      i += 5
      v = false
    else:
      error("Boolean true or false expected.", i)

proc parseHook*(s: string, i: var int, v: var SomeUnsignedInt) =
  ## Will parse unsigned integers.
  when nimvm:
    v = type(v)(parseInt(parseSymbol(s, i)))
  else:
    eatSpace(s, i)
    var
      v2: uint64 = 0
      startI = i
    while i < s.len and s[i] in {'0'..'9'}:
      v2 = v2 * 10 + (s[i].ord - '0'.ord).uint64
      inc i
    if startI == i:
      error("Number expected.", i)
    v = type(v)(v2)

proc parseHook*(s: string, i: var int, v: var SomeSignedInt) =
  ## Will parse signed integers.
  when nimvm:
    v = type(v)(parseInt(parseSymbol(s, i)))
  else:
    eatSpace(s, i)
    if i < s.len and s[i] == '-':
      var v2: uint64
      inc i
      parseHook(s, i, v2)
      v = -type(v)(v2)
    else:
      var v2: uint64
      parseHook(s, i, v2)
      try:
        v = type(v)(v2)
      except:
        error("Number type to small to contain the number.", i)

proc parseHook*(s: string, i: var int, v: var SomeFloat) =
  ## Will parse float32 and float64.
  v = type(v)(parseFloat(parseSymbol(s, i)))

proc parseHook*(s: string, i: var int, v: var string) =
  ## Parse string.
  eatSpace(s, i)
  if i + 3 < s.len and s[i+0] == 'n' and s[i+1] == 'u' and s[i+2] == 'l' and s[i+3] == 'l':
    i += 4
    return
  eatChar(s, i, '"')
  while i < s.len:
    let c = s[i]
    case c
    of '"':
      break
    of '\\':
      inc i
      let c = s[i]
      case c
      of '"', '\\', '/': v.add(c)
      of 'b': v.add '\b'
      of 'f': v.add '\f'
      of 'n': v.add '\n'
      of 'r': v.add '\r'
      of 't': v.add '\t'
      of 'u':
        inc i
        let u = parseHexInt(s[i ..< i + 4])
        i += 3
        v.add(Rune(u).toUTF8())
      else:
        v.add(c)
    else:
      v.add(c)
    inc i
  eatChar(s, i, '"')

proc parseHook*(s: string, i: var int, v: var char) =
  var str: string
  s.parseHook(i, str)
  if str.len != 1:
    error("String can't fit into a char.", i)
  v = str[0]

proc parseHook*[T](s: string, i: var int, v: var seq[T]) =
  ## Parse seq.
  eatChar(s, i, '[')
  while i < s.len:
    eatSpace(s, i)
    if i < s.len and s[i] == ']':
      break
    var element: T
    parseHook(s, i, element)
    v.add(element)
    eatSpace(s, i)
    if i < s.len and s[i] == ',':
      inc i
    else:
      break
  eatChar(s, i, ']')

proc parseHook*[T: tuple](s: string, i: var int, v: var T) =
  eatSpace(s, i)
  var strV: string
  eatChar(s, i, '[')
  for name, value in v.fieldPairs:
    eatSpace(s, i)
    parseHook(s, i, value)
    eatSpace(s, i)
    if i < s.len and s[i] == ',':
      inc i
  eatChar(s, i, ']')

proc parseHook*[T: array](s: string, i: var int, v: var T) =
  eatSpace(s, i)
  var strV: string
  eatChar(s, i, '[')
  for value in v.mitems:
    eatSpace(s, i)
    parseHook(s, i, value)
    eatSpace(s, i)
    if i < s.len and s[i] == ',':
      inc i
  eatChar(s, i, ']')

proc skipValue(s: string, i: var int) =
  ## Used to skip values of extra fields.
  eatSpace(s, i)
  if i < s.len and s[i] == '{':
    eatChar(s, i, '{')
    while i < s.len:
      eatSpace(s, i)
      if i < s.len and s[i] == '}':
        break
      skipValue(s, i)
      eatChar(s, i, ':')
      skipValue(s, i)
      eatSpace(s, i)
      if i < s.len and s[i] == ',':
        inc i
    eatChar(s, i, '}')
  elif i < s.len and s[i] == '[':
    eatChar(s, i, '[')
    while i < s.len:
      eatSpace(s, i)
      if i < s.len and s[i] == ']':
        break
      skipValue(s, i)
      eatSpace(s, i)
      if i < s.len and s[i] == ',':
        inc i
    eatChar(s, i, ']')
  elif i < s.len and s[i] == '"':
    var str: string
    parseHook(s, i, str)
  else:
    discard parseSymbol(s, i)

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

proc parseHook*[T: enum](s: string, i: var int, v: var T) =
  eatSpace(s, i)
  var strV: string
  if i < s.len and s[i] == '"':
    parseHook(s, i, strV)
    when compiles(enumHook(strV, v)):
      enumHook(strV, v)
    else:
      try:
        v = parseEnum[T](strV)
      except:
        error("Can't parse enum.", i)
  else:
    try:
      strV = parseSymbol(s, i)
      v = T(parseInt(strV))
    except:
      error("Can't parse enum.", i)

proc parseHook*[T: object|ref object](s: string, i: var int, v: var T) =
  ## Parse an object or ref object.
  eatSpace(s, i)
  if i + 3 < s.len and s[i+0] == 'n' and s[i+1] == 'u' and s[i+2] == 'l' and s[i+3] == 'l':
    i += 4
    return
  eatChar(s, i, '{')
  when not v.isObjectVariant:
    when compiles(newHook(v)):
      newHook(v)
    elif compiles(new(v)):
      new(v)
  else:
    # Look for the discriminatorFieldName
    eatSpace(s, i)
    var saveI = i
    while i < s.len:
      var key: string
      parseHook(s, i, key)
      eatChar(s, i, ':')
      if key == v.discriminatorFieldName:
        var discriminator: type(v.discriminatorField)
        parseHook(s, i, discriminator)
        new(v, discriminator)
        when compiles(newHook(v)):
          newHook(v)
        break
      skipValue(s, i)
      if i < s.len and s[i] == '}':
        error("No discriminator field.", i)
      eatChar(s, i, ',')
    i = saveI
  while i < s.len:
    eatSpace(s, i)
    if i < s.len and s[i] == '}':
      break
    var key: string
    parseHook(s, i, key)
    eatChar(s, i, ':')
    when compiles(renameHook(v, key)):
      renameHook(v, key)
    block all:
      for k, v in v.fieldPairs:
        if k == key or snakeCase(k) == key:
          var v2: type(v)
          parseHook(s, i, v2)
          v = v2
          break all
      skipValue(s, i)
    eatSpace(s, i)
    if i < s.len and s[i] == ',':
      inc i
    else:
      break
  when compiles(postHook(v)):
    postHook(v)
  eatChar(s, i, '}')

proc parseHook*[T](s: string, i: var int, v: var Option[T]) =
  ## Parse an Option.
  if i + 3 < s.len and s[i+0] == 'n' and s[i+1] == 'u' and s[i+2] == 'l' and s[i+3] == 'l':
    i += 4
    return
  var e: T
  parseHook(s, i, e)
  v = some(e)

proc parseHook*[T](s: string, i: var int, v: var SomeTable[string, T]) =
  ## Parse an object.
  when compiles(new(v)):
    new(v)
  eatChar(s, i, '{')
  while i < s.len:
    eatSpace(s, i)
    if i < s.len and s[i] == '}':
      break
    var key: string
    parseHook(s, i, key)
    eatChar(s, i, ':')
    var element: T
    parseHook(s, i, element)
    v[key] = element
    if i < s.len and s[i] == ',':
      inc i
    else:
      break
  eatChar(s, i, '}')

proc parseHook*[T](s: string, i: var int, v: var SomeSet[T]) =
  ## Parse HashSet.
  eatSpace(s, i)
  eatChar(s, i, '[')
  while true:
    eatSpace(s, i)
    if i < s.len and s[i] == ']':
      break
    var e: T
    parseHook(s, i, e)
    v.incl(e)
    eatSpace(s, i)
    if i < s.len and s[i] == ',':
      inc i
  eatChar(s, i, ']')

proc parseHook*(s: string, i: var int, v: var JsonNode) =
  ## Parses a regular json node.
  eatSpace(s, i)
  if i < s.len and s[i] == '{':
    v = newJObject()
    eatChar(s, i, '{')
    while i < s.len:
      eatSpace(s, i)
      if i < s.len and s[i] == '}':
        break
      var k: string
      parseHook(s, i, k)
      eatChar(s, i, ':')
      var e: JsonNode
      parseHook(s, i, e)
      v[k] = e
      eatSpace(s, i)
      if i < s.len and s[i] == ',':
        inc i
    eatChar(s, i, '}')
  elif i < s.len and s[i] == '[':
    v = newJArray()
    eatChar(s, i, '[')
    while i < s.len:
      eatSpace(s, i)
      if i < s.len and s[i] == ']':
        break
      var e: JsonNode
      parseHook(s, i, e)
      v.add(e)
      eatSpace(s, i)
      if i < s.len and s[i] == ',':
        inc i
    eatChar(s, i, ']')
  elif i < s.len and s[i] == '"':
    var str: string
    parseHook(s, i, str)
    v = newJString(str)
  else:
    var data = parseSymbol(s, i)
    if data == "null":
      v = newJNull()
    elif data == "true":
      v = newJBool(true)
    elif data == "false":
      v = newJBool(false)
    elif data.len > 0 and data[0] in {'0'..'9'}:
      if "." in data:
        try:
          v = newJFloat(parseFloat(data))
        except ValueError:
          error("Invalid integer.", i)
      else:
        try:
          v = newJInt(parseInt(data))
        except ValueError:
          error("Invalid float.", i)
    else:
      error("Unexpected.", i)

proc fromJson*[T](s: string, x: typedesc[T]): T =
  ## Takes json and outputs the object it represents.
  ## * Extra json fields are ignored.
  ## * Missing json fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.
  var i = 0
  s.parseHook(i, result)

proc fromJson*(s: string): JsonNode =
  ## Takes json parses it into `JsonNode`s.
  var i = 0
  s.parseHook(i, result)

proc dumpHook*(s: var string, v: bool)
proc dumpHook*(s: var string, v: uint|uint8|uint16|uint32|uint64)
proc dumpHook*(s: var string, v: int|int8|int16|int32|int64)
proc dumpHook*(s: var string, v: string)
proc dumpHook*(s: var string, v: char)
proc dumpHook*(s: var string, v: tuple)
proc dumpHook*(s: var string, v: enum)
proc dumpHook*[N, T](s: var string, v: array[N, T])
proc dumpHook*[T](s: var string, v: seq[T])
proc dumpHook*(s: var string, v: object)
proc dumpHook*(s: var string, v: ref object)

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

proc dumpHook*(s: var string, v: uint|uint8|uint16|uint32|uint64) =
  when nimvm:
    s.add $v.uint64
  else:
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

proc dumpHook*(s: var string, v: int|int8|int16|int32|int64) =
  if v < 0:
    s.add '-'
    dumpHook(s, 0.uint64 - v.uint64)
  else:
    dumpHook(s, v.uint64)

proc dumpHook*(s: var string, v: SomeFloat) =
  s.add $v

proc dumpHook*(s: var string, v: string) =
  when nimvm:
    s.add '"'
    for c in v:
      case c:
      of '\\': s.add r"\\"
      of '\b': s.add r"\b"
      of '\f': s.add r"\f"
      of '\n': s.add r"\n"
      of '\r': s.add r"\r"
      of '\t': s.add r"\t"
      else:
        s.add c
    s.add '"'
  else:
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
      else:
        ss.add c
    ss.add '"'
    s.setLen(at)

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

proc dumpHook*(s: var string, v: ref object) =
  if v == nil:
    s.add "null"
  else:
    s.dumpHook(v[])

proc dumpHook*[T](s: var string, v: HashSet[T]|OrderedSet[T]) =
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
