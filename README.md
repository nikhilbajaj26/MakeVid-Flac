# MakeVid-Flac
Interactively create youtube-ready videos from flac file(s) + image.
## Requirements
#### ffmpeg 4 
- [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
```
sudo add-apt-repository ppa:jonathonf/ffmpeg-4
sudo apt-get update
sudo apt-get install ffmpeg
```
- Mac w/ [Homebrew](https://brew.sh/)
```
brew install ffmpeg
```
#### ImageMagick
  - WSL
```
sudo apt-get install imagemagick
```
  - Mac
```
brew install imagemagick
```

#### Remember to make the script executable!
```
chmod +x makevid.sh
```
## Usage
- By default, makevid.sh will check the folder in which it is run for audio+images, as well as any immediate subdirectories. Run the script with the `r` flag (`makevid.sh r`) for a fully recursive search.
- Interactive mode allows you to customize video titles and tracklists, and to resize images to fit any widescreen resolution (720p, 1080p, custom). Quiet mode will not prompt for user input and will instead use the first image it finds + all flac files in a directory to make a video. Run the script with `i` or `q` flag to select the corresponding mode.
#### FYI
- Acceptable image extensions: png, jpg, jpeg. 
- The script will not modify any existing files nor generate any extraneous ones upon completion besides the mkv videos. 
- Audio files are not re-encoded at any point. Stream copy only.
- Note that image size has no bearing on audio quality when uploading to youtube. As of 6/13/2020, youtube uses the opus codec for all videos.
