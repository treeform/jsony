import macros, strutils, tables, unicode

type JsonError = object of ValueError

const whiteSpace = {' ', '\n', '\t', '\r'}

proc parseJson[T](s: string, i: var int, v: var seq[T])
proc parseJson[T:enum](s: string, i: var int, v: var T)
proc parseJson[T:object|ref object](s: string, i: var int, v: var T)
proc parseJson[T](s: string, i: var int, v: var Table[string, T])

template error(msg: string, i: int) =
  ## Short cut to raise an exception.
  raise newException(JsonError, msg)

proc eatSpace(s: string, i: var int) =
  ## Will consume white space.
  while i < s.len:
    let c = s[i]
    if c in whiteSpace:
      discard
    else:
      return
    inc i

proc eat(s: string, i: var int, c: char) =
  ## Will consume space before and then the character `c`.
  ## Will raise an exception if `c` is not found.
  eatSpace(s, i)
  if i >= s.len:
    error("Expected " & c & " but end reached.", i)
  if s[i] == c:
    inc i
  else:
    error("Expected " & c & " at offset.", i)

proc parseSymbol(s: string, i: var int): string =
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

proc parseJson(s: string, i: var int, v: var bool) =
  ## Will parse boolean true or false.
  case parseSymbol(s, i)
  of "true":
    v = true
  of "false":
    v = false
  else:
    error("Boolean true or false expected.", i)

proc parseJson(s: string, i: var int, v: var SomeInteger) =
  ## Will parse int8, uint8, int16, uint16, int32, uint32, int64, uint64 or
  ## just int.
  v = type(v)(parseInt(parseSymbol(s, i)))

proc parseJson(s: string, i: var int, v: var SomeFloat) =
  ## Will parse float32 and float64.
  v = type(v)(parseFloat(parseSymbol(s, i)))

proc parseJson(s: string, i: var int, v: var string) =
  ## Parse string.
  #echo "S:", s[i .. min(i + 80, s.len-1)]
  eatSpace(s, i)
  if s[i] == 'n':
    let what = parseSymbol(s, i)
    if what == "null":
      return
    else:
      error("Expected \" or null at offset.", i)
  eat(s, i, '"')
  var j = i
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
  eat(s, i, '"')

proc parseJson[T](s: string, i: var int, v: var seq[T]) =
  ## Parse seq.
  eat(s, i, '[')
  while i < s.len:
    eatSpace(s, i)
    if s[i] == ']':
      break
    var element: T
    parseJson(s, i, element)
    v.add(element)
    eatSpace(s, i)
    if s[i] == ',':
      inc i
    else:
      break
  eat(s, i, ']')

proc skipValue(s: string, i: var int) =
  ## Used to skip values of extra fields.
  #echo "Skip:", s[i .. min(i + 80, s.len-1)]
  eatSpace(s, i)
  if s[i] == '{':
    #echo "skip obj"
    eat(s, i, '{')
    while i < s.len:
      eatSpace(s, i)
      if s[i] == '}':
        break
      skipValue(s, i)
      eat(s, i, ':')
      skipValue(s, i)
      eatSpace(s, i)
      if s[i] == ',':
        inc i
    eat(s, i, '}')
  elif s[i] == '[':
    #echo "skip arr"
    eat(s, i, '[')
    while i < s.len:
      eatSpace(s, i)
      if s[i] == ']':
        break
      skipValue(s, i)
      eatSpace(s, i)
      if s[i] == ',':
        inc i
    eat(s, i, ']')
  elif s[i] == '"':
    #echo "skip str"
    var str: string
    parseJson(s, i, str)
  else:
    #echo "skip sym"
    discard parseSymbol(s, i)

proc camelCase(s: string): string =
  return s

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
        parseJson(s, i, value)
        v.`fieldName` = value
      ofClause.add(body)
      result.add(ofClause)
  let ofElseClause = nnkElse.newTree()
  let body = quote:
    skipValue(s, i)
  ofElseClause.add(body)
  result.add(ofElseClause)

proc parseJson[T:enum](s: string, i: var int, v: var T) =
  eatSpace(s, i)
  var strV: string
  if s[i] == '"':
    parseJson(s, i, strV)
    when compiles(enumHook(strV, v)):
      enumHook(strV, v)
    else:
      v = parseEnum[T](strV)
  else:
    strV = parseSymbol(s, i)
    v = T(parseInt(strV))

proc parseJson[T:object|ref object](s: string, i: var int, v: var T) =
  ## Parse an object.
  eatSpace(s, i)
  if s[i] == 'n':
    let what = parseSymbol(s, i)
    if what == "null":
      return
    else:
      error("Expected {} or null at offset.", i)
  eat(s, i, '{')
  when compiles(newHook(v)):
    newHook(v)
  elif compiles(new(v)):
    new(v)
  while i < s.len:
    eatSpace(s, i)
    if s[i] == '}':
      break
    var key: string
    parseJson(s, i, key)
    eat(s, i, ':')
    fieldsMacro(v, key)
    eatSpace(s, i)
    if s[i] == ',':
      inc i
    else:
      break
  eat(s, i, '}')

proc parseJson[T](s: string, i: var int, v: var Table[string, T]) =
  ## Parse an object.
  eat(s, i, '{')
  while i < s.len:
    eatSpace(s, i)
    if s[i] == '}':
      break
    var key: string
    parseJson(s, i, key)
    eat(s, i, ':')
    var element: T
    parseJson(s, i, element)
    v[key] = element
    if s[i] == ',':
      inc i
    else:
      break
  eat(s, i, '}')

proc fromJson*[T](s: string): T =
  ## Takes json and outputs the object it represents.
  ## * Create little intermediate values.
  ## * Extra json fields are ignored.
  ## * Missing json fields keep their default values.
  ## * `proc newHook(foo: var ...)` Can be used to populate default values.

  var i = 0
  parseJson(s, i, result)
