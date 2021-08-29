## Reduce your media disk consumption with HEVC!
A windows powershell script to re-encode media library videos to HEVC / H265 using ffmpeg on windows with GPU acceleration. 

### requirements
- ffmpeg executables for windows (includes gpu offload) - https://ffmpeg.org/download.html
- a GPU that is supported :) 

### usage 
- Download and place ffmpeg tools in same folder as script (windows - reccommend full gpl nightly build. https://github.com/BtbN/FFmpeg-Builds/releases) 
- Update variables.ps1 with your settings
- Run hevc_transcode.ps1 in powershell 

### warning! 
**Script will overwrite existing source files if conversion is successfull**

### functions
- traverses root path (scans all video files in subfolders) - as a job in background 
- transcodes video stream to hevc using **AMD or Nvidia GPU** (largest to smallest file) 
- copys all existing audio and subtitles (i.e. no conversion) 
- overwrites source with new HEVC transcode if **move_file = 1** (WARNING this is default!) 
- checks to see if video codec is already HEVC (if so, skips)
- checks that HEVC conversion is successful (using video length) and is smaller than origanal file (99.9% of time this is true) - if larger does not overwrite and skips file 
- convert_1080p - if enabled will transcode larger resolutions down to 1080p HEVC 
- writes **hevc_transcode.log** for logging :) 

### limitations (potential todo list) 
Deminishing effort vs reward - 
- does not change media container to mkv if source is another container format
- does not have a progress status during transcode 
