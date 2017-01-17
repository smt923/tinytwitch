import irc, times, terminal, random, strutils, strtabs, os
from rawsockets import Port

const
  CHAT_URL = "irc.chat.twitch.tv"
  CHAT_PORT = Port(6667)

var
  shouldLog = false
# check if a string contains some text that can be found in a set
# there's probably a cleaner/smarter way to do this, will update at some point
proc hasTextInSet(str: string, s: seq): bool =
  var bHighlight = false
  for i in s:
    if str.contains(i):
      bHighlight = true
      break
    else:
      bHighlight = false
      continue
  return bHighlight

# add a hash to the channel name if there isn't one there already
proc addHash(s: string): string =
  if s.startsWith('#'):
    return s
  else:
    return "#"&s

# anonymous account generation (justinfan + 14 random numbers)
proc randomTwitchUser(): string =
  random.randomize(epochTime().int)
  var name = "justinfan"
  for i in 0..13:
      name &= strutils.intToStr(random.random(9))
  return name 

# add ascii versions of twitch badges such as subscriber and moderator
proc addTwitchBadges(s: string, e: IrcEvent): string =
  result = s
  if e.tags.len() >= 12:
    if e.tags["subscriber"] == "1":
      result &= "[S]"
    if e.tags["mod"] == "1":
      result &= "[M]"
  result &= " "&e.nick

proc logToFile(f: File, s: string) =
  if shouldLog:
    f.writeLine(s)

var chans = newSeq[string](0)
var highlights = newSeq[string](0)
if paramCount() == 0:
  echo("Type the usernames of the channels to join, seperated by spaces: ")
  var channelin: string = readLine(stdin)
  for chan in splitWhitespace(channelin): 
    chans.add(addHash(chan.toLowerAscii()))

elif paramCount() >= 1:
  for param in commandLineParams():
    chans.add(addHash(param.toLowerAscii()))

echo("Type the words you wish to highlight, seperated by spaces (or just press enter for none): ")
var highlightin: string = readLine(stdin)
if not highlightin.isNilOrWhitespace(): 
  for hl in splitWhitespace(highlightin):
    highlights.add(hl)

echo("Do you want to log the chat to a file? (y = yes, just press enter for no)")
var loggingin: string = readLine(stdin)
if loggingin.contains("y") or loggingin.contains("yes"):
  shouldLog = true

var username = randomTwitchUser()
var t = irc.newIrc(CHAT_URL, CHAT_PORT , username, username,
                    joinChans = chans)
var curtime: string

t.connect()
# this gives us things such as userlist, joins, parts and mod status:
t.send("CAP REQ :twitch.tv/membership twitch.tv/commands twitch.tv/tags", false) 

var chatline = ""
var filename = getDateStr()&"_twitchchat_log.txt"
var f: File 
if shouldLog:
  if f.open(filename):
    discard f.open(filename, fmAppend)
  else:
    discard f.open(filename, fmReadWrite)

system.addQuitProc(resetAttributes)

while true:
  var event: IrcEvent
  if t.poll(event):
    curtime = "["&getClockStr()&"]"
    case event.typ
    of EvConnected:
      chatline = "$1 - [INFO] Connected to server" % [curtime]
      styledWriteLine(stdout, fgWhite, chatline)
      f.logToFile(chatline)
    of EvDisconnected:
      chatline = "$1 - [ERR] Disconnected, reconnecting..." % [curtime]
      styledWriteLine(stdout, fgRed, chatline)
      f.logToFile(chatline)
      t.reconnect()
    of EvTimeout:
      chatline = "$1 - [ERR] Timeout, reconnecting..." % [curtime]
      styledWriteLine(stdout, fgRed, chatline)
      f.logToFile(chatline)
      t.reconnect()
    of EvMsg:
      case event.cmd 
        of MPrivMsg:
          var username = ""
          username = username.addTwitchBadges(event).strip()
          if event.user == "twitchnotify":
            chatline = "$1 $2 - [SUB] $3" % [curtime, event.origin, event.params[1]]
            styledWriteLine(stdout, fgWhite, bgMagenta, styleBright, chatline)
            f.logToFile(chatline)      
          elif event.params[1].hasTextInSet(highlights):
            chatline = "$1 $2 - [MSG] $3: $4" % [curtime, event.origin, username, event.params[1]]
            styledWriteLine(stdout, fgWhite, bgRed, styleBright, chatline)
            f.logToFile(chatline)              
          else:
            chatline = "$1 $2 - [MSG] $3: $4" % [curtime, event.origin, username, event.params[1]]
            styledWriteLine(stdout, fgWhite, chatline)
            f.logToFile(chatline)
        of MJoin:
          chatline = "$1 $2 - [JOIN] $3" % [curtime, event.origin, event.nick]
          styledWriteLine(stdout, fgGreen, chatline)
          f.logToFile(chatline)
        of MPart:
          chatline = "$1 $2 - [PART] $3" % [curtime, event.origin, event.nick]
          styledWriteLine(stdout, fgRed, chatline)
          f.logToFile(chatline)
        of MMode:
          if event.params[1] == "+o":
            chatline = "$1 $2 - [+MOD] $3" % [curtime, event.origin, event.params[2]]
            styledWriteLine(stdout, fgCyan, chatline)
            f.logToFile(chatline)
          elif event.params[1] == "-o":
            chatline = "$1 $2 - [-MOD] $3" % [curtime, event.origin, event.params[2]]
            styledWriteLine(stdout, fgCyan, chatline)
            f.logToFile(chatline)
        of MUnknown:
          if event.raw.contains(" CLEARCHAT "):
            chatline = "$1 $2 - [INFO] $3 was timed out for $4 seconds" % [curtime, event.origin, event.params[1], event.tags["ban-duration"]]
            styledWriteLine(stdout, fgWhite, chatline)
            f.logToFile(chatline)
          elif event.raw.contains(" USERNOTICE "):
            var submsgs = event.tags["system-msg"]
            var submsg  = ""
            if submsgs.contains(".") and event.params.len() <= 1:
              submsg = submsgs.split(".")[1].replace(r"\s", " ").strip()
              chatline = "$1 $2 - [SUB] $3" % [curtime, event.origin, submsg]
              styledWriteLine(stdout, fgWhite, bgMagenta, styleBright, chatline)
              f.logToFile(chatline)
            elif submsgs.contains(".") and event.params.len() >= 2:
              submsg = submsgs.split(".")[1].replace(r"\s", " ").strip()
              chatline = "$1 $2 - [SUB] $3 - $4" % [curtime, event.origin, submsg, event.params[1]]
              styledWriteLine(stdout, fgWhite, bgMagenta, styleBright, chatline)
              f.logToFile(chatline)
            elif event.params.len() <= 1:
              submsg = submsgs.replace(r"\s", " ").strip()
              chatline = "$1 $2 - [SUB] $3" % [curtime, event.origin, submsg]
              styledWriteLine(stdout, fgWhite, bgMagenta, styleBright, chatline)
              f.logToFile(chatline)
            else:
              submsg = submsgs.replace(r"\s", " ").strip()
              chatline = "$1 $2 - [SUB] $3 - $4" % [curtime, event.origin, submsg, event.params[1]]
              styledWriteLine(stdout, fgWhite, bgMagenta, styleBright, chatline) 
              f.logToFile(chatline)             
        else:
          discard

f.close()