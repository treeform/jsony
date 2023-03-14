import benchy, jason, jsony

const
  number11 = 11
  stringHello = "Hello"
  seqOfInts = @[1, 2, 3, 4, 5, 6, 7]

timeIt "treeform/jsony number", 100:
  for i in 0 .. 1000:
    discard number11.toStaticJson()

timeIt "disruptek/jason number", 100:
  for i in 0 .. 1000:
    discard number11.jason.string

timeIt "treeform/jsony string", 100:
  discard stringHello.toStaticJson()

timeIt "disruptek/jason string", 100:
  for i in 0 .. 1000:
    discard stringHello.jason.string

timeIt "treeform/jsony seq", 100:
  for i in 0 .. 1000:
    discard seqOfInts.toStaticJson()

timeIt "disruptek/jason seq", 100:
  for i in 0 .. 1000:
    discard seqOfInts.jason.string

type
  Some = object
    goats: array[4, string]
    sheep: int
    ducks: float
    dogs: string
    cats: bool
    fish: seq[uint64]
    llama: (int, bool, string, float)
    frogs: tuple[toads: bool, rats: string]
    geese: (int, int, int, int, int)

const
  thing = Some(
    goats: ["black", "pigs", "pink", "horses"],
    sheep: 11, ducks: 12.0,
    fish: @[8'u64, 6, 7, 5, 3, 0, 9],
    dogs: "woof", cats: false,
    llama: (1, true, "secret", 42.0),
    geese: (9, 0, 2, 1, 0),
    frogs: (toads: true, rats: "yep")
  )

timeIt "treeform/jsony object", 100:
  for i in 0 .. 1000:
    discard thing.toStaticJson()

timeIt "disruptek/jason object", 100:
  for i in 0 .. 1000:
    discard thing.jason.string
