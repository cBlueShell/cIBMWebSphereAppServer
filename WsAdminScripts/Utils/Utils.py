def wsadminToList(inStr):
    outList=[]
    if (len(inStr)>0 and inStr[0]=='[' and inStr[-1]==']'):
        inStr = inStr[1:-1]
        tmpList = inStr.split(" ")
    else:
        tmpList = inStr.split("\n") #splits for Windows or Linux
    for item in tmpList:
        item = item.rstrip();       #removes any Windows "\r"
        if (len(item)>0):
           outList.append(item)
    return outList
#endDef