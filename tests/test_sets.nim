import jsony, sets

block:
  let
    s1 = toHashSet([9, 5, 1])
    s2 = toOrderedSet([3, 5, 7])

  doAssert s1.toJson() == "[9,1,5]"
  doAssert s2.toJson() == "[3,5,7]"

  doAssert s1.toJson.fromJson(type(s1)) == s1
  doAssert s2.toJson.fromJson(type(s2)) == s2
