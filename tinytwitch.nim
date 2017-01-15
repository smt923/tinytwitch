import
  irc, times, terminal, random, strutils, os
from rawsockets import Port

const
  CHAT_URL = "irc.chat.twitch.tv"
  CHAT_PORT = Port(6667)

# helper function to clean up some (messier than this) code
proc colorPrint(s: string, c: ForegroundColor): void =
  setForegroundColor(c)
  echo(s)
  setForegroundColor(fgWhite)

# add a hash to the channel name if there isn't one there already
proc addHash(s: string): string =
  var str = s
  if s.startsWith('#'):
    return str
  else:
    str = "#"&str
    return str

# anonymous account generation (justinfan + 14 random numbers)
proc randomTwitchUser(): string=
  random.randomize(epochTime().int)
  var name = "justinfan"
  for i in 0..13:
      name &= strutils.intToStr(random.random(9))
  return name 

var chans = newSeq[string](0)
if paramCount() == 0:
  echo("Type the usernames of the channels to join, seperated by a space: ")
  var channel: string = readLine(stdin)
  for chan in splitWhitespace(channel): 
    chans.add(addHash(chan))
elif paramCount() >= 1:
  for param in commandLineParams():
    chans.add(addHash(param))

var username = randomTwitchUser()
var t = irc.newIrc(CHAT_URL, CHAT_PORT , username, username,
                    joinChans = chans)
var curtime: string

t.connect()
# this gives us things such as userlist, joins, parts and mod status:
t.send("CAP REQ :twitch.tv/membership", false) 

while true:
  var event: IrcEvent
  if t.poll(event):
    curtime = "["&getClockStr()&"] "
    case event.typ
    of EvConnected: echo(curtime & "- [INFO] Connected to server")
    of EvDisconnected:
      colorPrint(curtime & "- [ERR] Timeout, reconnecting...", fgRed)
      t.reconnect()
    of EvTimeout:
      colorPrint(curtime & "- [ERR] Timeout, reconnecting...", fgRed)
      t.reconnect()
    of EvMsg:
      case event.cmd 
        of MPrivMsg: 
          colorPrint(curtime & event.origin & " - [MSG] " & event.nick & ": " & event.params[1], fgWhite)
        of MJoin:
          colorPrint(curtime & event.origin & " - [JOIN] " & event.nick, fgYellow)
        of MPart:
          colorPrint(curtime & event.origin & " - [PART] " & event.nick, fgYellow)
        of MMode:
          if event.params[1] == "+o":
            colorPrint(curtime & event.origin & " - [+MOD] " & event.params[2], fgCyan)
          elif event.params[1] == "-o":
            colorPrint(curtime & event.origin & " - [-MOD] " & event.params[2], fgCyan)
        else:
          discard