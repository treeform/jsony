import jsony

type Color = enum
  cRed
  cBlue
  cGreen

doAssert "0".fromJson(Color) == cRed
doAssert "1".fromJson(Color) == cBlue
doAssert "2".fromJson(Color) == cGreen

doAssert """ "cRed" """.fromJson(Color) == cRed
doAssert """ "cBlue" """.fromJson(Color) == cBlue
doAssert """ "cGreen" """.fromJson(Color) == cGreen

type Color2 = enum
  c2Red
  c2Blue
  c2Green

proc enumHook(s: string, v: var Color2) =
  v = case s:
  of "RED": c2Red
  of "BLUE": c2Blue
  of "GREEN": c2Green
  else: c2Red

doAssert """ "RED" """.fromJson(Color2) == c2Red
doAssert """ "BLUE" """.fromJson(Color2) == c2Blue
doAssert """ "GREEN" """.fromJson(Color2) == c2Green
