import jsony

block:
  var s = "[1, 2, 3]"
  var v = fromJson[(int, int, int)](s)
  doAssert v[0] == 1
  doAssert v[1] == 2
  doAssert v[2] == 3

block:
  var s = """[1, "hi", 3.5]"""
  var v = fromJson[(int, string, float32)](s)
  doAssert v[0] == 1
  doAssert v[1] == "hi"
  doAssert v[2] == 3.5

block:
  type Entry = tuple[id:int, name:string, dist:float32]
  var s = """[134, "red", 13.5]"""
  var v = fromJson[Entry](s)
  doAssert v[0] == 134
  doAssert v[1] == "red"
  doAssert v[2] == 13.5
  doAssert v.id == 134
  doAssert v.name == "red"
  doAssert v.dist == 13.5

block:
  type Vector3i = tuple[x:int, y:int, z:int]
  var s = """[0, 1, 2]"""
  var v = fromJson[Vector3i](s)
  doAssert v[0] == 0
  doAssert v[1] == 1
  doAssert v[2] == 2
  doAssert v.x == 0
  doAssert v.y == 1
  doAssert v.z == 2
