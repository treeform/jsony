import jsony

type Color = enum
  cRed
  cBlue
  cGreen

doAssert fromJson[Color]("0") == cRed
doAssert fromJson[Color]("1") == cBlue
doAssert fromJson[Color]("2") == cGreen

doAssert fromJson[Color](""" "cRed" """) == cRed
doAssert fromJson[Color](""" "cBlue" """) == cBlue
doAssert fromJson[Color](""" "cGreen" """) == cGreen

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
