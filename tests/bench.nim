import benchy, random, json, jsony, eminim, streams, jsutils/jsons

type Node = ref object
  kind: string
  name: string
  id: int
  kids: seq[Node]

var r = initRand(2020)
var genId: int
proc genTree(depth: int): Node =
  result = Node()
  result.id = genId
  inc genId
  result.name = "node" & $result.id
  result.kind = "NODE"
  if depth > 0:
    for i in 0 .. r.rand(0..3):
      result.kids.add genTree(depth - 1)

var tree = genTree(10)
var treeStr = pretty %tree

echo genId, " node tree:"

timeIt "treeform/jsony":
  keep jsony.fromJson[Node](treeStr)

timeIt "nim std/json":
  keep parseJson(treeStr).to(Node)

timeIt "treeform/jsutils/jsons":
  keep jsons.fromJson(parseJson(treeStr), Node)

timeIt "planetis-m/eminim":
  keep newStringStream(treeStr).jsonTo(Node)