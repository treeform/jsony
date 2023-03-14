import jsony

block:
  var s = "[1, 2, 3]"
  var v = s.fromJson((int, int, int))
  doAssert v[0] == 1
  doAssert v[1] == 2
  doAssert v[2] == 3

block:
  var s = """[1, "hi", 3.5]"""
  var v = s.fromJson((int, string, float32))
  doAssert v[0] == 1
  doAssert v[1] == "hi"
  doAssert v[2] == 3.5

block:
  type Vector3i = tuple[x: int, y: int, z: int]
  var s = """[0, 1, 2]"""
  var v = s.fromJson(Vector3i)
  doAssert v[0] == 0
  doAssert v[1] == 1
  doAssert v[2] == 2
  doAssert v.x == 0
  doAssert v.y == 1
  doAssert v.z == 2

block:
  type Entry = tuple[id: int, name: string, dist: float32]
  var s = """[134, "red", 13.5]"""
  var v = s.fromJson(Entry)
  doAssert v[0] == 134
  doAssert v[1] == "red"
  doAssert v[2] == 13.5
  doAssert v.id == 134
  doAssert v.name == "red"
  doAssert v.dist == 13.5

block:
  type Entry = tuple[id: int, name: string, dist: float32]
  var s = """{"id": 134, "name": "red", "dist": 13.5}"""
  var v = s.fromJson(Entry)
  doAssert v[0] == 134
  doAssert v[1] == "red"
  doAssert v[2] == 13.5
  doAssert v.id == 134
  doAssert v.name == "red"

block:
  type Entry = tuple[id: int, name: string, dist: float32]
  var s = """[{"id": 134, "name": "red", "dist": 13.5}]"""
  var entries = s.fromJson(seq[Entry])
  doAssert entries.len == 1
  var v = entries[0]
  doAssert v.dist == 13.5
  doAssert v[0] == 134
  doAssert v[1] == "red"
  doAssert v[2] == 13.5
  doAssert v.id == 134
  doAssert v.name == "red"
  doAssert v.dist == 13.5

type EntryForHook = tuple[id: int, name: string]
proc postHook(entry: var EntryForHook) =
  entry.id = 42

block:
  var s = """{"id": 6, "name": "red"}"""
  var v = s.fromJson(EntryForHook)
  doAssert v.id == 42
  doAssert v.name == "red"
