import jsony

block:
  doAssert fromJson[bool]("true") == true
  doAssert fromJson[bool]("false") == false
  doAssert fromJson[bool](" true  ") == true
  doAssert fromJson[bool]("  false    ") == false

  doAssert fromJson[int]("1") == 1
  doAssert fromJson[int]("12") == 12
  doAssert fromJson[int]("  123  ") == 123

  doAssert fromJson[int8](" 123 ") == 123
  doAssert fromJson[uint8](" 123 ") == 123
  doAssert fromJson[int16](" 123 ") == 123
  doAssert fromJson[uint16](" 123 ") == 123
  doAssert fromJson[int32](" 123 ") == 123
  doAssert fromJson[uint32](" 123 ") == 123
  doAssert fromJson[int64](" 123 ") == 123
  doAssert fromJson[uint64](" 123 ") == 123

  doAssert fromJson[int8](" -99 ") == -99
  doAssert fromJson[int16](" -99 ") == -99
  doAssert fromJson[int32](" -99 ") == -99
  doAssert fromJson[int64](" -99 ") == -99

  doAssert fromJson[float32](" 1.34E3 ") == 1.34E3
  doAssert fromJson[float32](" 1.34E3 ") == 1.34E3
  doAssert fromJson[float64](" -1.34E3 ") == -1.34E3
  doAssert fromJson[float64](" -1.34E3 ") == -1.34E3

block:
  doAssert fromJson[seq[int]]("[1, 2, 3]") == @[1, 2, 3]
  doAssert fromJson[seq[string]]("""["hi", "bye", "maybe"]""") ==
    @["hi", "bye", "maybe"]
  doAssert fromJson[seq[seq[string]]]("""[["hi", "bye"], ["maybe"], []]""") ==
    @[@["hi", "bye"], @["maybe"], @[]]
