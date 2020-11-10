## Reduce your media disk consumption with HEVC!
This is a windows powershell script to re-encode media library videos to HEVC / H265 using ffmpeg on windows with GPU h/w acceleration. 

### requirements
- ffmpeg executables for windows (includes hevc_amf) - https://ffmpeg.org/download.html
- a GPU that is supported :) 

### usage 
- place ffmpeg tools in same folder as script 
- Update variables in script then run in powershell 

### warning! 
**It will overwrite existing source files if conversion is successfull**

### functions
- traverses root path (scans all files in subfolders) 
- transcodes video stream to hevc using **AMD or Nvidia /w encoder** 
- copys all existing audio and subtitles (i.e. no conversion) 
- able to set min time before re-scanning disk 
- overwrites source with new HEVC transcode if **move_file = 1** (WARNING this is default!) 
- checks to see if video codec is already HEVC (if so, skips)
- checks that HEVC conversion is smaller than origanal file (99.9% of time this is true) - if larger does not overwrite and skips file 
- if enabled - will transcode larger resolutions down to 1080p HEVC (this is default) 
- writes **transcode.log** for transcode attempts (duration and space savings) 
- writes **skip.log** for already hevc and failed transcodes (used to skip in next loop, errors in transcode.log) 

### limitations (potential todo list) 
Deminishing effort vs reward - 
- does not change media container to mkv if source is another container format

