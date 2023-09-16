import jsony

block:
  var s = "[1, 2, 3]"
  var v = s.fromJson(array[3, int])
  doAssert v[0] == 1
  doAssert v[1] == 2
  doAssert v[2] == 3

block:
  var s = "[1.5, 2.25, 3.0]"
  var v = s.fromJson(array[3, float32])
  doAssert v[0] == 1.5
  doAssert v[1] == 2.25
  doAssert v[2] == 3.0

block:
  var s = """["no", "yes"]"""
  var v = s.fromJson(array[2, string])
  doAssert v[0] == "no"
  doAssert v[1] == "yes"

block:
  var s = """["no", "yes"]"""
  var v = s.fromJson(ref array[2, string])
  doAssert v[0] == "no"
  doAssert v[1] == "yes"

block:
  var s = "null"
  var v = s.fromJson(ref array[2, string])
  doAssert v == nil

block:
  var s = "[1, 2, 3] asdf"
  doAssertRaises JsonError:
    discard s.fromJson(array[3, int])
