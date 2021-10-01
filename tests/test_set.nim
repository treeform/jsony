import jsony

#set[int8], set[int16]
block:
  let
    s1: set[int8] = {1'i8, 2, 3}
    s2: set[int16] = {1'i16, 2, 3}

  doAssert s1.toJson() == "[1,2,3]"
  doAssert s2.toJson() == "[1,2,3]"

  doAssert s1.toJson.fromJson(set[int8]) == s1
  doAssert s2.toJson.fromJson(set[int16]) == s2

#set[uint8], set[uint16]
block:
  let
    s1: set[uint8] = {1'u8, 2, 3}
    s2: set[uint16] = {1'u16, 2, 3}

  doAssert s1.toJson() == "[1,2,3]"
  doAssert s2.toJson() == "[1,2,3]"

  doAssert s1.toJson.fromJson(set[uint8]) == s1
  doAssert s2.toJson.fromJson(set[uint16]) == s2

#set[char]
block:
  let
    s1: set[char] = {'0'..'9'}

  doAssert s1.toJson() == """["0","1","2","3","4","5","6","7","8","9"]"""

  doAssert s1.toJson.fromJson(set[char]) == s1

#set[enum]
block:
  type
    E1 = enum
      e1Elem1, e1Elem2, e1Elem3
    E2 = enum
      e2Elem1 = "custString1", e2Elem2 = "custString2", e2Elem3 = "custString3"
    E3 = enum
      e3Elem1 = 10, e3Elem2 = 20, e3Elem3 = 30

  let
    s1: set[E1] = {e1Elem1, e1Elem2, e1Elem3}
    s2: set[E2] = {e2Elem1, e2Elem2, e2Elem3}
    s3: set[E3] = {e3Elem1, e3Elem2, e3Elem3}

  doAssert s1.toJson() == """["e1Elem1","e1Elem2","e1Elem3"]"""
  doAssert s2.toJson() == """["custString1","custString2","custString3"]"""
  doAssert s3.toJson() == """["e3Elem1","e3Elem2","e3Elem3"]"""

  doAssert s1.toJson.fromJson(set[E1]) == s1
  doAssert s2.toJson.fromJson(set[E2]) == s2
  doAssert s3.toJson.fromJson(set[E3]) == s3

#type set[enum]
block:
  type
    E1 = enum
      e1Elem1, e1Elem2, e1Elem3
    S1 = set[E1]

  let
    s1: S1 = {e1Elem1, e1Elem2, e1Elem3}

  doAssert s1.toJson() == """["e1Elem1","e1Elem2","e1Elem3"]"""

  doAssert s1.toJson.fromJson(set[E1]) == s1

#object with set[enum]
block:
  type
    E1 = enum
      e1Elem1, e1Elem2, e1Elem3
    O1 = object
      e1: set[E1]

  let
    o1: O1 = O1(e1: {e1Elem1, e1Elem2, e1Elem3})

  doAssert o1.toJson() == """{"e1":["e1Elem1","e1Elem2","e1Elem3"]}"""

  doAssert o1.toJson.fromJson(O1) == o1

#ref object with set[enum]
block:
  type
    E1 = enum
      e1Elem1, e1Elem2, e1Elem3
    O1 = ref object
      e1: set[E1]

  let
    o1: O1 = O1(e1: {e1Elem1, e1Elem2, e1Elem3})

  doAssert o1.toJson() == """{"e1":["e1Elem1","e1Elem2","e1Elem3"]}"""

  doAssert o1.toJson.fromJson(O1)[] == o1[]
