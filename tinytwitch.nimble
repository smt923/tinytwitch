# Package

version       = "0.1.0"
author        = "smt"
description   = "Very simple, very lightweight Twitch.tv chat viewer"
license       = "MIT"
bin           = @["tinytwitch"]
skipExt       = @["nim"]

# Dependencies

requires "nim >= 0.16.0"
requires "irc"
