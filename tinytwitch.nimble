# Package

version       = "0.3.0"
author        = "smt"
description   = "Very simple, very lightweight Twitch.tv chat viewer"
license       = "MIT"

bin           = @["tinytwitch"]
skipExt       = @["nim"]
srcDir        = "src"

# Dependencies

requires "nim >= 0.16.0"
requires "irc >= 0.1.0"
requires "parsetoml >= 0.2.0"
