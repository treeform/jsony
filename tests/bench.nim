import benchy, random, streams
import jsony, jason
import eminim
#import packedjson, packedjson/deserialiser
import json

type Node = ref object
  active: bool
  kind: string
  name: string
  id: int
  kids: seq[Node]

var r = initRand(2020)
var genId: int
proc genTree(depth: int): Node =
  result = Node()
  result.id = genId
  if r.rand(0 .. 1) == 0:
    result.active = true
  inc genId
  result.name = "node" & $result.id
  result.kind = "NODE"
  if depth > 0:
    for i in 0 .. r.rand(0..3):
      result.kids.add genTree(depth - 1)
    for i in 0 .. r.rand(0..3):
      result.kids.add nil

var tree = genTree(10)

var treeStr = tree.toJson()

echo genId, " node tree:"

timeIt "treeform/jsony", 100:
  keep jsony.fromJson[Node](treeStr)

timeIt "nim std/json", 100:
  keep json.to(json.parseJson(treeStr), Node)

# timeIt "araq/packedjson", 100:
#   keep deserialiser.to(packedjson.parseJson(treeStr), Node)

timeIt "planetis-m/eminim", 100:
  keep newStringStream(treeStr).jsonTo(Node)

# timeIt "disruptek/jason", 100:
#   discard

echo "serialize:"

timeIt "treeform/jsony", 100:
  keep tree.toJson()

timeIt "nim std/json", 100:
  keep json.`$`(json.`%`(tree))

# timeIt "araq/packedjson", 100:
#   keep packedjson.`$`(packedjson.`%`(tree))

timeIt "planetis-m/eminim", 100:
  var s = newStringStream()
  s.storeJson(tree)
  s.setPosition(0)
  keep s.data

timeIt "disruptek/jason", 100:
  keep tree.jason
