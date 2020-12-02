import jsony

block:
  var s = "[1, 2, 3]"
  var v = fromJson[array[3, int]](s)
  doAssert v[0] == 1
  doAssert v[1] == 2
  doAssert v[2] == 3

block:
  var s = "[1.5, 2.25, 3.0]"
  var v = fromJson[array[3, float32]](s)
  doAssert v[0] == 1.5
  doAssert v[1] == 2.25
  doAssert v[2] == 3.0

block:
  var s = """["no", "yes"]"""
  var v = fromJson[array[2, string]](s)
  doAssert v[0] == "no"
  doAssert v[1] == "yes"
