import jsony

type
  Message = object
    id: uint64
    data: RawJson

let
  messageData = """{"id":123,"data":{"page":"base64","arr":[1,2,3]}}"""
  message = messageData.fromJson(Message)
# make sure raw json was not parsed
doAssert message.data.string == """{"page":"base64","arr":[1,2,3]}"""
# make sure that dumping raw json produces same result
doAssert message.toJson() == messageData
