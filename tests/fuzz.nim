import jsony, os, random, strformat, strutils, tables

type
  NodeKind = enum
    nkRed, nkBlue, nkGreen, nkBlack
  Node = ref object
    active: bool
    kind: NodeKind
    name: string
    tup: (int8, uint16, int32, uint64)
    id: int
    kids: seq[Node]
    table: Table[string, uint8]
    body: string

var r = initRand(2020)
var genId: int
proc genTree(depth: int): Node =
  result = Node()
  result.id = genId
  result.tup[0] = r.rand(0 .. int8.high.int).int8
  result.tup[1] = r.rand(0 .. uint16.high.int).uint16
  result.tup[2] = r.rand(0 .. int32.high.int).int32
  result.tup[3] = r.rand(0 .. int.high).uint64
  inc genId
  if r.rand(0 .. 1) == 0:
    result.active = true
  result.name = "node" & $result.id
  result.kind = [nkRed, nkBlue, nkGreen, nkBlack][r.rand(0 .. 3)]
  result.table["cat"] = 4
  result.table["dog"] = 4
  result.body = "abc🔒\n"
  if depth > 0:
    for i in 0 .. r.rand(0..3):
      result.kids.add genTree(depth - 1)
    for i in 0 .. r.rand(0..3):
      result.kids.add nil

let
  treeStr = genTree(5).toJson()

randomize()

for i in 0 ..< 10000:
  var
    data = treeStr
    pos = rand(data.high)
    value = rand(255).char
    #pos = 18716
    #value = 125.char

  data[pos] = value
  echo &"{i} {pos} {value.uint8}"
  try:
    let node = data.fromJson(Node)
    doAssert node != nil
  except CatchableError:
    discard

  var data2 = data[0 ..< pos]
  try:
    let node = data2.fromJson(Node)
    doAssert node != nil
  except CatchableError:
    discard

  # JsonNode
  try:
    let node = data.fromJson()
    doAssert node != nil
  except CatchableError:
    discard

  try:
    let node = data2.fromJson()
    doAssert node != nil
  except CatchableError:
    discard
