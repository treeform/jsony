import macros, strutils, tables, unicode

type JsonError = object of ValueError

const whiteSpace = {' ', '\n', '\t', '\r'}

proc parseHook*[T](s: string, i: var int, v: var seq[T])
proc parseHook*[T: enum](s: string, i: var int, v: var T)
proc parseHook*[T: object|ref object](s: string, i: var int, v: var T)
proc parseHook*[T](s: string, i: var int, v: var Table[string, T])
proc parseHook*[T: tuple](s: string, i: var int, v: var T)
proc parseHook*[T: array](s: string, i: var int, v: var T)

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
    if i + 3 < s.len and s[i+0] == 't' or s[i+1] == 'r' or s[i+2] == 'u' or s[i+3] == 'e':
      i += 4
      v = true
    elif i + 4 < s.len and s[i+0] == 'f' or s[i+1] == 'a' or s[i+2] == 'l' or s[i+3] == 's' or s[i+4] == 'e':
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
    var v2: uint64 = 0
    while i < s.len and s[i] in {'0'..'9'}:
      v2 = v2 * 10 + (s[i].ord - '0'.ord).uint64
      inc i
    v = type(v)(v2)

proc parseHook*(s: string, i: var int, v: var SomeSignedInt) =
  ## Will parse signed integers.
  when nimvm:
    v = type(v)(parseInt(parseSymbol(s, i)))
  else:
    eatSpace(s, i)
    if s[i] == '-':
      var v2: uint64
      inc i
      parseHook(s, i, v2)
      v = -type(v)(v2)
    else:
      var v2: uint64
      parseHook(s, i, v2)
      v = type(v)(v2)

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

proc parseHook*[T](s: string, i: var int, v: var seq[T]) =
  ## Parse seq.
  eatChar(s, i, '[')
  while i < s.len:
    eatSpace(s, i)
    if s[i] == ']':
      break
    var element: T
    parseHook(s, i, element)
    v.add(element)
    eatSpace(s, i)
    if s[i] == ',':
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
    if s[i] == ',':
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
    if s[i] == ',':
      inc i
  eatChar(s, i, ']')

proc skipValue(s: string, i: var int) =
  ## Used to skip values of extra fields.
  eatSpace(s, i)
  if s[i] == '{':
    eatChar(s, i, '{')
    while i < s.len:
      eatSpace(s, i)
      if s[i] == '}':
        break
      skipValue(s, i)
      eatChar(s, i, ':')
      skipValue(s, i)
      eatSpace(s, i)
      if s[i] == ',':
        inc i
    eatChar(s, i, '}')
  elif s[i] == '[':
    eatChar(s, i, '[')
    while i < s.len:
      eatSpace(s, i)
      if s[i] == ']':
        break
      skipValue(s, i)
      eatSpace(s, i)
      if s[i] == ',':
        inc i
    eatChar(s, i, ']')
  elif s[i] == '"':
    var str: string
    parseHook(s, i, str)
  else:
    discard parseSymbol(s, i)

proc camelCase(s: string): string =
  return s

proc snakeCase(s: string): string =
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

macro fieldsMacro(v: typed, key: string) =
  ## Crates a parser for object fields.
  result = nnkCaseStmt.newTree(ident"key")
  # Get implementation of v's type.
  var impl = getTypeImpl(v)
  # Walk refs and pointers to the real type.
  while impl.kind in {nnkRefTy, nnkPtrTy}:
    impl = getTypeImpl(impl[0])
  # For each field in the type:
  var used: seq[string]
  for f in impl[2]:
    # Get fields name and type information.
    let fieldName = f[0]
    let filedNameStr = fieldName.strVal()
    let filedType = f[1]
    # Output a name/type checker for it:
    for fn in [camelCase, snakeCase]:
      let caseName = fn(filedNameStr)
      if caseName in used:
        continue
      used.add(caseName)
      let ofClause = nnkOfBranch.newTree(newLit(caseName))
      let body = quote:
        var value: `filedType`
        parseHook(s, i, value)
        v.`fieldName` = value
      ofClause.add(body)
      result.add(ofClause)
  let ofElseClause = nnkElse.newTree()
  let body = quote:
    skipValue(s, i)
  ofElseClause.add(body)
  result.add(ofElseClause)

proc parseHook*[T: enum](s: string, i: var int, v: var T) =
  eatSpace(s, i)
  var strV: string
  if s[i] == '"':
    parseHook(s, i, strV)
    when compiles(enumHook(strV, v)):
      enumHook(strV, v)
    else:
      v = parseEnum[T](strV)
  else:
    strV = parseSymbol(s, i)
    v = T(parseInt(strV))

proc parseHook*[T: object|ref object](s: string, i: var int, v: var T) =
  ## Parse an object.
  eatSpace(s, i)
  # if s[i] == 'n':
  #   let what = parseSymbol(s, i)
  #   if what == "null":
  #     return
  #   else:
  #     error("Expected {} or null.", i)
  if i + 3 < s.len and s[i+0] == 'n' and s[i+1] == 'u' and s[i+2] == 'l' and s[i+3] == 'l':
    i += 4
    return
  eatChar(s, i, '{')
  when compiles(newHook(v)):
    newHook(v)
  elif compiles(new(v)):
    new(v)
  while i < s.len:
    eatSpace(s, i)
    if s[i] == '}':
      break
    var key: string
    parseHook(s, i, key)
    eatChar(s, i, ':')
    when compiles(renameHook(v, key)):
      renameHook(v, key)
    fieldsMacro(v, key)
    eatSpace(s, i)
    if s[i] == ',':
      inc i
    else:
      break
  when compiles(postHook(v)):
    postHook(v)
  eatChar(s, i, '}')

proc parseHook*[T](s: string, i: var int, v: var Table[string, T]) =
  ## Parse an object.
  eatChar(s, i, '{')
  while i < s.len:
    eatSpace(s, i)
    if s[i] == '}':
      break
    var key: string
    parseHook(s, i, key)
    eatChar(s, i, ':')
    var element: T
    parseHook(s, i, element)
    v[key] = element
    if s[i] == ',':
      inc i
    else:
      break
  eatChar(s, i, '}')

proc fromJson*[T](s: string): T =
  ## Takes json and outputs the object it represents.
  ## * Extra json fields are ignored.
  ## * Missing json fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.

  var i = 0
  parseHook(s, i, result)

proc dumpHook*(s: var string, v: bool)
proc dumpHook*(s: var string, v: uint|uint8|uint16|uint32|uint64)
proc dumpHook*(s: var string, v: int|int8|int16|int32|int64)
proc dumpHook*(s: var string, v: string)
proc dumpHook*(s: var string, v: char)
proc dumpHook*(s: var string, v: tuple)
proc dumpHook*[N, T](s: var string, v: array[N, T])
proc dumpHook*[T](s: var string, v: seq[T])
proc dumpHook*(s: var string, v: object)
proc dumpHook*(s: var string, v: ref object)

proc dumpHook*(s: var string, v: bool) =
  if v:
    s.add "true"
  else:
    s.add "false"

when defined(release):
  {.push checks: off.}

const lookup = ['0', '0', '0', '1', '0', '2', '0', '3', '0', '4', '0', '5', '0', '6', '0', '7', '0', '8', '0', '9', '1', '0', '1', '1', '1', '2', '1', '3', '1', '4', '1', '5', '1', '6', '1', '7', '1', '8', '1', '9', '2', '0', '2', '1', '2', '2', '2', '3', '2', '4', '2', '5', '2', '6', '2', '7', '2', '8', '2', '9', '3', '0', '3', '1', '3', '2', '3', '3', '3', '4', '3', '5', '3', '6', '3', '7', '3', '8',
'3', '9', '4', '0', '4', '1', '4', '2', '4', '3', '4', '4', '4', '5', '4', '6', '4', '7', '4', '8', '4', '9', '5', '0', '5', '1', '5', '2', '5', '3', '5', '4', '5', '5', '5', '6', '5', '7', '5', '8', '5', '9', '6', '0', '6', '1', '6', '2', '6', '3', '6', '4', '6', '5', '6', '6', '6', '7', '6', '8', '6', '9', '7', '0', '7', '1', '7', '2', '7', '3', '7', '4', '7', '5', '7', '6', '7', '7', '7', '8', '7', '9', '8', '0', '8', '1', '8', '2', '8', '3', '8', '4', '8', '5', '8', '6', '8', '7',
'8', '8', '8', '9', '9', '0', '9', '1', '9', '2', '9', '3', '9', '4', '9', '5', '9', '6', '9', '7', '9', '8', '9', '9', '1', '0', '0']

template grow(s: var string, amount: int) =
  s.setLen(s.len + amount)

proc dumpHook*(s: var string, v: uint|uint8|uint16|uint32|uint64) =
  when nimvm:
    s.add $v
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
    s.grow(p)
    dec p
    var ss = cast[ptr UncheckedArray[char]](s[0].addr)
    while p >= 0:
      ss[at] = digits[p]
      dec p
      inc at

proc dumpHook*(s: var string, v: int|int8|int16|int32|int64) =
  if v < 0:
    s.add '-'
    dumpHook(s, 0.uint64 - v.uint64)
  else:
    dumpHook(s, v.uint64)

when defined(release):
  {.pop.}

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
    s.grow(v.len*2+2)

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
