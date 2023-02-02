import benchy, eminim, jason, jsony, macros, random, streams
when defined(packedjson):
  import packedjson, packedjson/deserialiser
else:
  import json
when not defined(gcArc):
  import serialization
  import json_serialization except Json, toJson
#from deser_json import parse, to

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
  inc genId
  if r.rand(0 .. 1) == 0:
    result.active = true
  result.name = "node" & $result.id
  result.kind = "NODE"
  if depth > 0:
    for i in 0 .. r.rand(0..3):
      result.kids.add genTree(depth - 1)
    for i in 0 .. r.rand(0..3):
      result.kids.add nil

var tree = genTree(10)

var treeStr = tree.toJson()
echo treeStr[0 ..< 100]
echo genId, " node tree:"

timeIt "treeform/jsony", 100:
  keep treeStr.fromJson(Node)

when not defined(gcArc):
  timeIt "status-im/nim-json-serialization", 100:
    keep json_serialization.Json.decode(treeStr, Node)

timeIt "planetis-m/eminim", 100:
  keep newStringStream(treeStr).jsonTo(Node)

when defined(packedjson):
  timeIt "araq/packedjson", 100:
    keep deserialiser.to(packedjson.parseJson(treeStr), Node)
else:
  timeIt "nim std/json", 100:
    keep json.to(json.parseJson(treeStr), Node)

# timeIt "gabbhack/deser_json", 100:
#   TODO: fix m.tokens[pos].kind == JSMN_OBJECT ...
#   keep treeStr.parse().to(Node)

echo "serialize:"

timeIt "treeform/jsony", 100:
  keep tree.toJson()

when not defined(gcArc):
  timeIt "status-im/nim-json-serialization", 100:
    keep json_serialization.Json.encode(tree)
  doAssert json_serialization.Json.encode(tree) == treeStr

timeIt "planetis-m/eminim", 100:
  var s = newStringStream()
  s.storeJson(tree)
  s.setPosition(0)
  keep s.data

timeIt "disruptek/jason", 100:
  keep tree.jason.string

when defined(packedjson):
  timeIt "araq/packedjson", 100:
    keep packedjson.`$`(packedjson.`%`(tree))
else:
  timeIt "nim std/json", 100:
    keep json.`$`(json.`%`(tree))
