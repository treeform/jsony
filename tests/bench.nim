import benchy, random, json, jsony, eminim, streams, jsutils/jsons
from packedjson import parseJson, toJsonNode
from packedjson/deserialiser import to

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

var treeStr = $(%tree)
var treePrettyStr = json.pretty(%tree)

echo genId, " node tree:"

timeIt "treeform/jsony":
  keep jsony.fromJson[Node](treeStr)

timeIt "treeform/jsony pretty":
  keep jsony.fromJson[Node](treePrettyStr)

timeIt "nim std/json":
  keep json.parseJson(treeStr).to(Node)

timeIt "araq/packedjson":
  keep packedjson.parseJson(treeStr)

timeIt "araq/packedjson with to":
  keep deserialiser.to(packedjson.parseJson(treeStr).toJsonNode(), Node)

timeIt "treeform/jsutils/jsons":
  keep jsons.fromJson(json.parseJson(treeStr), Node)

timeIt "planetis-m/eminim":
  keep newStringStream(treeStr).jsonTo(Node)

timeIt "planetis-m/eminim pretty":
  keep newStringStream(treePrettyStr).jsonTo(Node)