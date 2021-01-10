import jsony

doAssert """ "a" """.fromJson(char) == 'a'
doAssert """["a"]""".fromJson(seq[char]) == @['a']
doAssert """["a", "b", "c"]""".fromJson(seq[char]) == @['a', 'b', 'c']
doAssert 'a'.toJson() == """"a""""
doAssert 'b'.toJson() == """"b""""
