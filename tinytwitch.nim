import irc, times, terminal, random, strutils, strtabs, os
import parsetoml
from rawsockets import Port

var cfg: File
if not cfg.open("settings.toml"):
  echo "ERROR: settings.toml file not found!"
  discard readChar(stdin)
  quit 1

type
  ChatColors = object
    chat, error, join, part, mods: ForegroundColor
    highlight, subs: BackgroundColor

const
  CHAT_URL = "irc.chat.twitch.tv"
  CHAT_PORT = Port(6667)

let
  config = parsetoml.parseFile("settings.toml")

var
  shouldLog = false
  linecounter = 0

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

proc getFgColor(str: string): ForegroundColor =
  case str:
    of "white": return fgWhite
    of "black": return fgBlack
    of "red": return fgRed
    of "green": return fgGreen
    of "yellow": return fgYellow
    of "blue": return fgBlue
    of "magenta": return fgMagenta
    of "cyan": return fgCyan
    else: discard

proc getBgColor(str: string): BackgroundColor =
  case str:
    of "white": return bgWhite
    of "black": return bgBlack
    of "red": return bgRed
    of "green": return bgGreen
    of "yellow": return bgYellow
    of "blue": return bgBlue
    of "magenta": return bgMagenta
    of "cyan": return bgCyan
    else: discard

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

# small wrapper for cleaner code, writes file and flushes every X lines
proc logToFile(f: File, s: string) =
  if shouldLog:
    f.writeLine(s)
    linecounter += 1
    if linecounter >= config.getInt("general.log_save_lines"):
      f.flushFile()
      linecounter = 0

let chatColor: ref ChatColors = new(ChatColors)

chatColor.chat = getFgColor(config.getString("colors.chat"))
chatColor.error = getFgColor(config.getString("colors.error"))
chatColor.join = getFgColor(config.getString("colors.join"))
chatColor.part = getFgColor(config.getString("colors.part"))
chatColor.mods = getFgColor(config.getString("colors.modstatus"))

chatColor.highlight = getBgColor(config.getString("colors.highlight"))
chatColor.subs = getBgColor(config.getString("colors.subnotice"))

var 
  chans = newSeq[string](0)
  highlights = newSeq[string](0)

if config.getBool("general.use_config_channels") == false:
  echo("Type the usernames of the channels to join, seperated by spaces: ")
  var channelin: string = readLine(stdin)
  for chan in splitWhitespace(channelin): 
    chans.add(addHash(chan.toLowerAscii()))
else:
  for chan in config.getStringArray("general.channels"):
    chans.add(addHash(chan.toLowerAscii()))

for highlight in config.getStringArray("general.highlights"):
    if not highlight.isNilOrWhitespace():
      highlights.add(highlight)

if config.getBool("general.logging") == true:
  shouldLog = true
else:
  shouldLog = false

var username = randomTwitchUser()
var t = irc.newIrc(CHAT_URL, CHAT_PORT , username, username,
                    joinChans = chans)

var curtime: string
t.connect()
# this gives us things such as userlist, joins, parts and mod status:
t.send("CAP REQ :twitch.tv/membership twitch.tv/commands twitch.tv/tags", false) 

var chatline = ""
var f: File
if shouldLog:
  var filename = getDateStr()&"_twitchchat_log.txt"
  if f.open(filename):
    discard f.open(filename, fmAppend)
  else:
    discard f.open(filename, fmReadWrite)

addQuitProc(resetAttributes)

while true:
  var event: IrcEvent
  if t.poll(event):
    curtime = "["&getClockStr()&"]"
    case event.typ
    of EvConnected:
      chatline = "$1 - [INFO] Connected to server" % [curtime]
      styledWriteLine(stdout, chatColor.chat, chatline)
      f.logToFile(chatline)

    of EvDisconnected:
      chatline = "$1 - [ERR] Disconnected, reconnecting..." % [curtime]
      styledWriteLine(stdout, chatColor.error, chatline)
      f.logToFile(chatline)
      t.reconnect()

    of EvTimeout:
      chatline = "$1 - [ERR] Timeout, reconnecting..." % [curtime]
      styledWriteLine(stdout, chatColor.error, chatline)
      f.logToFile(chatline)
      t.reconnect()

    of EvMsg:
      case event.cmd 
        of MPrivMsg:
          var username = ""
          username = username.addTwitchBadges(event).strip()
          if event.user == "twitchnotify":
            chatline = "$1 $2 - [SUB] $3" % [curtime, event.origin, event.params[1]]
            styledWriteLine(stdout, chatColor.chat, chatColor.subs, styleBright, chatline)
            f.logToFile(chatline)      
          elif event.params[1].hasTextInSet(highlights):
            chatline = "$1 $2 - [MSG] $3: $4" % [curtime, event.origin, username, event.params[1]]
            styledWriteLine(stdout, chatColor.chat, chatColor.highlight, styleBright, chatline)
            f.logToFile(chatline)              
          else:
            chatline = "$1 $2 - [MSG] $3: $4" % [curtime, event.origin, username, event.params[1]]
            styledWriteLine(stdout, chatColor.chat, chatline)
            f.logToFile(chatline)

        of MJoin:
          chatline = "$1 $2 - [JOIN] $3" % [curtime, event.origin, event.nick]
          styledWriteLine(stdout, chatColor.join, chatline)
          f.logToFile(chatline)

        of MPart:
          chatline = "$1 $2 - [PART] $3" % [curtime, event.origin, event.nick]
          styledWriteLine(stdout, chatColor.part, chatline)
          f.logToFile(chatline)

        of MMode:
          if event.params[1] == "+o":
            chatline = "$1 $2 - [+MOD] $3" % [curtime, event.origin, event.params[2]]
            styledWriteLine(stdout, chatColor.mods, chatline)
            f.logToFile(chatline)
          elif event.params[1] == "-o":
            chatline = "$1 $2 - [-MOD] $3" % [curtime, event.origin, event.params[2]]
            styledWriteLine(stdout, chatColor.mods, chatline)
            f.logToFile(chatline)
            
        of MUnknown:
          if event.raw.contains(" CLEARCHAT "):
            chatline = "$1 $2 - [INFO] $3 was timed out for $4 seconds" % [curtime, event.origin, event.params[1], event.tags["ban-duration"]]
            styledWriteLine(stdout, chatColor.chat, chatline)
            f.logToFile(chatline)
          elif event.raw.contains(" USERNOTICE "):
            var submsgs = event.tags["system-msg"]
            var submsg  = ""
            if submsgs.contains(".") and event.params.len() <= 1:
              submsg = submsgs.split(".")[1].replace(r"\s", " ").strip()
              chatline = "$1 $2 - [SUB] $3" % [curtime, event.origin, submsg]
              styledWriteLine(stdout, chatColor.chat, chatColor.subs, styleBright, chatline)
              f.logToFile(chatline)
            elif submsgs.contains(".") and event.params.len() >= 2:
              submsg = submsgs.split(".")[1].replace(r"\s", " ").strip()
              chatline = "$1 $2 - [SUB] $3 - $4" % [curtime, event.origin, submsg, event.params[1]]
              styledWriteLine(stdout, chatColor.chat, chatColor.subs, styleBright, chatline)
              f.logToFile(chatline)
            elif event.params.len() <= 1:
              submsg = submsgs.replace(r"\s", " ").strip()
              chatline = "$1 $2 - [SUB] $3" % [curtime, event.origin, submsg]
              styledWriteLine(stdout, chatColor.chat, chatColor.subs, styleBright, chatline)
              f.logToFile(chatline)
            else:
              submsg = submsgs.replace(r"\s", " ").strip()
              chatline = "$1 $2 - [SUB] $3 - $4" % [curtime, event.origin, submsg, event.params[1]]
              styledWriteLine(stdout, chatColor.chat, chatColor.subs, styleBright, chatline) 
              f.logToFile(chatline)             
        else:
          discard

f.close()