import irc, times, terminal, random, strutils, os
from rawsockets import Port

const
  CHAT_URL = "irc.chat.twitch.tv"
  CHAT_PORT = Port(6667)

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
    curtime = "["&getClockStr()&"]"
    case event.typ
    of EvConnected:
      styledWriteLine(stdout, fgWhite, "$1 - [INFO] Connected to server" % [curtime])
    of EvDisconnected:
      styledWriteLine(stdout, fgRed, "$1 - [ERR] Disconnected, reconnecting..." % [curtime])
      t.reconnect()
    of EvTimeout:
      styledWriteLine(stdout, fgRed, "$1 - [ERR] Timeout, reconnecting..." % [curtime])
      t.reconnect()
    of EvMsg:
      case event.cmd 
        of MPrivMsg: 
          styledWriteLine(stdout, fgWhite, "$1 $2 - [MSG] $3: $4" % [curtime, event.origin, event.nick, event.params[1]])
        of MJoin:
          styledWriteLine(stdout, fgYellow, "$1 $2 - [JOIN] $3" % [curtime, event.origin, event.nick])
        of MPart:
          styledWriteLine(stdout, fgYellow, "$1 $2 - [PART] $3" % [curtime, event.origin, event.nick])
        of MMode:
          if event.params[1] == "+o":
            styledWriteLine(stdout, fgCyan, "$1 $2 - [+MOD] $3" % [curtime, event.origin, event.params[2]])
          elif event.params[1] == "-o":
            styledWriteLine(stdout, fgCyan, "$1 $2 - [-MOD] $3" % [curtime, event.origin, event.params[2]])
        else:
          discard