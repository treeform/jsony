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
  raise newException(JsonError, msg)

proc eatSpace*(s: string, i: var int) =
  ## Will consume whitespace.
  while i < s.len:
    let c = s[i]
    if c notin whiteSpace:
      break
    inc i

proc eatChar*(s: string, i: var int, c: char) =
  ## Will consume space before and then the character `c`.
  ## Will raise an exception if `c` is not found.
  eatSpace(s, i)
  if i >= s.len:
    error("Expected " & c & " but end reached.", i)
  if s[i] == c:
    inc i
  else:
    error("Expected " & c & " at offset.", i)

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
  case parseSymbol(s, i)
  of "true":
    v = true
  of "false":
    v = false
  else:
    error("Boolean true or false expected.", i)

proc parseHook*(s: string, i: var int, v: var SomeInteger) =
  ## Will parse int8, uint8, int16, uint16, int32, uint32, int64, uint64 or
  ## just int.
  v = type(v)(parseInt(parseSymbol(s, i)))

proc parseHook*(s: string, i: var int, v: var SomeFloat) =
  ## Will parse float32 and float64.
  v = type(v)(parseFloat(parseSymbol(s, i)))

proc parseHook*(s: string, i: var int, v: var string) =
  ## Parse string.
  eatSpace(s, i)
  if s[i] == 'n':
    let what = parseSymbol(s, i)
    if what == "null":
      return
    else:
      error("Expected \" or null at offset.", i)
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
  if s[i] == 'n':
    let what = parseSymbol(s, i)
    if what == "null":
      return
    else:
      error("Expected {} or null at offset.", i)
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

proc dumpHook*(s: var string, v: bool) =
  if v:
    s.add "true"
  else:
    s.add "false"

proc dumpHook*(s: var string, v: SomeNumber) =
  s.add $v

proc dumpHook*(s: var string, v: string) =
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

proc dumpHook*(s: var string, v: char) =
  s.add '"'
  s.add v
  s.add '"'

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
      s.dumpHook(k)
      s.add ':'
      s.dumpHook(e)
      inc i
  s.add '}'

proc dumpHook*(s: var string, v: ref object) =
  if v == nil:
    s.add "null"
  else:
    s.dumpHook(v[])

proc dumpHook*(s: var string, v: tuple) =
  s.add '['
  var i = 0
  for _, e in v.fieldPairs:
    if i > 0:
      s.add ','
    s.dumpHook(e)
    inc i
  s.add ']'

proc dumpHook*[T](s: var string, v: openarray[T]) =
  s.add '['
  for i, e in v:
    if i != 0:
      s.add ','
    s.dumpHook(e)
  s.add ']'

proc toJson*[T](v: T): string =
  dumpHook(result, v)
