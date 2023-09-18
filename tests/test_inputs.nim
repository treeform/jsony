import jsony, random, strutils, tables

type
  NodeKind = enum
    nkRed, nkBlue, nkGree, nkBlack
  Node = ref object
    active: bool
    kind: NodeKind
    name: string
    tup: (int8, uint16, int32, uint64, float64)
    id: int
    kids: seq[Node]
    table: Table[string, uint8]

var r = initRand(2020)
var genId: int
proc genTree(depth: int): Node =
  result = Node()
  result.id = genId
  result.tup[0] = r.rand(0 .. int8.high.int).int8
  result.tup[1] = r.rand(0 .. uint16.high.int).uint16
  result.tup[2] = r.rand(0 .. int32.high.int).int32
  result.tup[3] = r.rand(0 .. int.high).uint64
  result.tup[4] = r.rand(float64.low .. float64.high).float64
  inc genId
  if r.rand(0 .. 1) == 0:
    result.active = true
  result.name = "node" & $result.id
  result.kind = [nkRed, nkBlue, nkGree, nkBlack][r.rand(0 .. 3)]
  result.table["cat"] = 4
  result.table["dog"] = 4
  if depth > 0:
    for i in 0 .. r.rand(0..3):
      result.kids.add genTree(depth - 1)
    for i in 0 .. r.rand(0..3):
      result.kids.add nil

let
  tree = genTree(5)
  treeStr = tree.toJson()

block:
  let
      tree2 = treeStr.toOpenArray(0, treeStr.len-1).fromJson(Node)
      tree2Str = tree2.toJson()
  doAssert treeStr == tree2Str

block:
  let
      tree2 = toOpenArray[char](treeStr,0, treeStr.len-1).fromJson(Node)
      tree2Str = tree2.toJson()
  doAssert treeStr == tree2Str

block:
  var asSeq: seq[char] = newSeq[char](treeStr.len)
  for i in 0 ..< treeStr.len:
    asSeq[i] = treeStr[i]
  let
      tree2 =  asSeq.fromJson(Node)
      tree2Str = tree2.toJson()
  doAssert treeStr == tree2Str

block:
  var asSeq: seq[char] = newSeq[char](treeStr.len)
  for i in 0 ..< treeStr.len:
    asSeq[i] = treeStr[i]
  let
      tree2 =  asSeq.fromJson(Node)
      tree2Str = tree2.toJson()
  doAssert treeStr == tree2Str
