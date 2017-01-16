import irc, times, terminal, random, strutils, os
from rawsockets import Port

const
  CHAT_URL = "irc.chat.twitch.tv"
  CHAT_PORT = Port(6667)
  #HIGHLIGHT = "smt"

# add a hash to the channel name if there isn't one there already
proc addHash(s: string): string =
  if s.startsWith('#'):
    return s
  else:
    return "#"&s

# anonymous account generation (justinfan + 14 random numbers)
proc randomTwitchUser(): string=
  random.randomize(epochTime().int)
  var name = "justinfan"
  for i in 0..13:
      name &= strutils.intToStr(random.random(9))
  return name 

var chans = newSeq[string](0)
var highlights = newSeq[string](0)
if paramCount() == 0:
  echo("Type the usernames of the channels to join, seperated by a space: ")
  var channelin: string = readLine(stdin)
  for chan in splitWhitespace(channelin): 
    chans.add(addHash(chan))

  echo("Type the phrases you wish to highlight (or just press enter for none)")
  var highlightin: string = readLine(stdin)
  if not highlightin.isNilOrWhitespace(): 
    for hl in splitWhitespace(highlightin):
      highlights.add(hl)
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

var shouldHighlight = false
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
          #TODO: almost certainly a better way to do this:
          for i in highlights:
            if event.params[1].contains(i):
              shouldHighlight = true
              break
            else:
              shouldHighlight = false
              continue
          if shouldHighlight:
            styledWriteLine(stdout, fgWhite, bgRed, "$1 $2 - [MSG] $3: $4" % [curtime, event.origin, event.nick, event.params[1]])              
          else:
            styledWriteLine(stdout, fgWhite, "$1 $2 - [MSG] $3: $4" % [curtime, event.origin, event.nick, event.params[1]])
        of MJoin:
          styledWriteLine(stdout, fgGreen, "$1 $2 - [JOIN] $3" % [curtime, event.origin, event.nick])
        of MPart:
          styledWriteLine(stdout, fgRed, "$1 $2 - [PART] $3" % [curtime, event.origin, event.nick])
        of MMode:
          if event.params[1] == "+o":
            styledWriteLine(stdout, fgCyan, "$1 $2 - [+MOD] $3" % [curtime, event.origin, event.params[2]])
          elif event.params[1] == "-o":
            styledWriteLine(stdout, fgCyan, "$1 $2 - [-MOD] $3" % [curtime, event.origin, event.params[2]])
        else:
          discard