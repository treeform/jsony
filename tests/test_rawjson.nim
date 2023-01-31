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

# you can also parse the json at some other time
type
  DataPayload = object
    page: string
    arr: seq[uint8]
let dp = message.data.string.fromJson(DataPayload)
doAssert dp.page == "base64"
doAssert dp.arr == @[1.uint8,2,3]
