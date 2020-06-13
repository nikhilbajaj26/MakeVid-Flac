# MakeVideo-flac
Create a youtube-ready video from flac file(s)+image

Not yet tested on a mac.

## Requirements
ffmpeg 4 (see AClassicalPlaylist-DL for instructions all platform)

also imagemagick. 
```
sudo apt-get install imagemagick
```
on WSL. Mac, homebrew works fine. Still have to check if bash 3 will be OK. Probably yes.

## How to use
Create folders, each containing flacs/images you want to make into video. Run script in parent directory, if you run in interactive mode you can resize images/edit tracklists, and title your videos. Quiet mode = script will choose first image it finds and use all flac files in whichever order they appear. 

Enjoy :) No reencoding, none of your files modified, videos should have minimal file size and should encode fairly quick (depends on your CPU).
