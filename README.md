# tinytwitch
tinytwitch is a twitch chat viewer with not many features (no emotes, you can only view chat, etc) but a very small footprint
([less than 1.5mb ram and 0.02 cpu usage when connected to the current top 10 streamer's chats](http://i.imgur.com/frpVkMO.png))

This makes it much more lightweight than using a browser and much more simple than using a full IRC client just for twitch

If you're just looking for the downloads, [click here](https://github.com/smt923/tinytwitch/releases) 

![tinytwitch](http://i.imgur.com/t6B0Syj.png)

## Usage
Either run the program with the streamer's chatrooms as arguments:
```
tinytwitch.exe bobross summit1g lirik
```
Or run the program and it will prompt you to enter streamers in the same format:
```
$ tinytwitch.exe
Type the usernames of the channels to join, seperated by a space:
bobross summit1g lirik
``` 
You can of course just enter a single channel

## What is it for?
This was mostly made for fun and to test the awesome language it's made in, [Nim](http://nim-lang.org/). You'll probably immediately know if you have use for this or not, if you don't feel like
leaving a resource hog browser running but still want your chat up, or maybe you want to leave a friend's/streamer you moderate's
chat up while playing a game and lanuch a browser when you need to step in and moderate

## Building
You'll need [Nim](http://nim-lang.org/) to build the program your self, simply running
```
$ nimble install
``` 
should install the program, or it can be built simply with
```
$ nim c -d:release tinytwitch.nim
```