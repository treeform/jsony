import benchy, random, streams
import jsony, jason
import eminim
when defined(packedjson):
  import packedjson, packedjson/deserialiser
else:
  import json
when not defined(gcArc):
  import serialization
  import json_serialization except Json, toJson


# timeIt "treeform/jsony", 100:
#   keep jsony.fromJson[Node](treeStr)

# when not defined(gcArc):
#   timeIt "status-im/nim-json-serialization", 100:
#     keep json_serialization.Json.decode(treeStr, Node)

block:
  echo "serialize int:"
  var number42: uint64 = 42

  timeIt "$", 100:
    for i in 0 ..< 1000:
      keep $number42

  timeIt "treeform/jsony", 100:
    for i in 0 ..< 1000:
      keep number42.toJson()

  timeIt "disruptek/jason", 100:
    for i in 0 ..< 1000:
      keep number42.jason.string

  when not defined(gcArc):
    timeIt "status-im/nim-json-serialization", 100:
      for i in 0 ..< 1000:
        keep json_serialization.Json.encode(number42)


block:
  echo "serialize string:"
  var hello = "Hello"

  timeIt "'$'", 100:
    for i in 0 ..< 1000:
      keep '"' & hello & '"'

  timeIt "treeform/jsony", 100:
    for i in 0 ..< 1000:
      keep hello.toJson()

  timeIt "disruptek/jason", 100:
    for i in 0 ..< 1000:
      keep hello.jason.string

  when not defined(gcArc):
    timeIt "status-im/nim-json-serialization", 100:
      for i in 0 ..< 1000:
        keep json_serialization.Json.encode(hello)

block:
  echo "serialize seq:"
  var numArray = @[1, 2, 3, 4, 5, 6, 7, 8, 9]

  timeIt "treeform/jsony", 100:
    for i in 0 ..< 1000:
      keep numArray.toJson()

  timeIt "disruptek/jason", 100:
    for i in 0 ..< 1000:
      keep numArray.jason.string

  when not defined(gcArc):
    timeIt "status-im/nim-json-serialization", 100:
      for i in 0 ..< 1000:
        keep json_serialization.Json.encode(numArray)

block:
  echo "serialize obj:"
  type Node = ref object
    active: bool
    kind: string
    name: string
    id: int
    kids: seq[Node]
  var node = Node()

  timeIt "treeform/jsony", 100:
    for i in 0 ..< 1000:
      keep node.toJson()

  timeIt "disruptek/jason", 100:
    for i in 0 ..< 1000:
      keep node.jason.string

  when not defined(gcArc):
    timeIt "status-im/nim-json-serialization", 100:
      for i in 0 ..< 1000:
        keep json_serialization.Json.encode(node)
