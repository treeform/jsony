import jsony

block:
  doAssert "true".fromJson(bool) == true
  doAssert "false".fromJson(bool) == false
  doAssert " true  ".fromJson(bool) == true
  doAssert "  false    ".fromJson(bool) == false

  doAssert "1".fromJson(int) == 1
  doAssert "12".fromJson(int) == 12
  doAssert "  123  ".fromJson(int) == 123

  doAssert " 123 ".fromJson(int8) == 123
  doAssert " 123 ".fromJson(uint8) == 123
  doAssert " 123 ".fromJson(int16) == 123
  doAssert " 123 ".fromJson(uint16) == 123
  doAssert " 123 ".fromJson(int32) == 123
  doAssert " 123 ".fromJson(uint32) == 123
  doAssert " 123 ".fromJson(int64) == 123
  doAssert " 123 ".fromJson(uint64) == 123

  doAssert " -99 ".fromJson(int8) == -99
  doAssert " -99 ".fromJson(int16) == -99
  doAssert " -99 ".fromJson(int32) == -99
  doAssert " -99 ".fromJson(int64) == -99

  doAssert " +99 ".fromJson(int8) == 99
  doAssert " +99 ".fromJson(int16) == 99
  doAssert " +99 ".fromJson(int32) == 99
  doAssert " +99 ".fromJson(int64) == 99

  doAssert " 1.25 ".fromJson(float32) == 1.25
  doAssert " 1.25 ".fromJson(float32) == 1.25
  doAssert " +1.25 ".fromJson(float64) == 1.25
  doAssert " +1.25 ".fromJson(float64) == 1.25
  doAssert " -1.25 ".fromJson(float64) == -1.25
  doAssert " -1.25 ".fromJson(float64) == -1.25

  doAssert " 1.34E3 ".fromJson(float32) == 1.34E3
  doAssert " 1.34E3 ".fromJson(float32) == 1.34E3
  doAssert " +1.34E3 ".fromJson(float64) == 1.34E3
  doAssert " +1.34E3 ".fromJson(float64) == 1.34E3
  doAssert " -1.34E3 ".fromJson(float64) == -1.34E3
  doAssert " -1.34E3 ".fromJson(float64) == -1.34E3

  doAssert "9e-8".fromJson(float64) == 9e-8

  doAssert toOpenArray(" 1.34E3 ",0, 7).fromJson(float32) == 1.34E3
  doAssert toOpenArray(" 1.34E3 ",0, 7).fromJson(float32) == 1.34E3
  doAssert toOpenArray(" +1.34E3 ",0, 8).fromJson(float64) == 1.34E3
  doAssert toOpenArray(" +1.34E3 ",0, 8).fromJson(float64) == 1.34E3
  doAssert toOpenArray(" -1.34E3 ",0, 8).fromJson(float64) == -1.34E3
  doAssert toOpenArray(" -1.34E3 ",0, 8).fromJson(float64) == -1.34E3

block:
  doAssert "[1, 2, 3]".fromJson(seq[int]) == @[1, 2, 3]
  doAssert """["hi", "bye", "maybe"]""".fromJson(seq[string]) ==
    @["hi", "bye", "maybe"]
  doAssert """[["hi", "bye"], ["maybe"], []]""".fromJson(seq[seq[string]]) ==
    @[@["hi", "bye"], @["maybe"], @[]]
