## Reduce your media disk consumption with HEVC!
A windows powershell script to re-encode media library videos to HEVC / H265 using ffmpeg on windows with GPU acceleration. 

### requirements
- ffmpeg executables for windows (includes gpu offload) - https://ffmpeg.org/download.html
- a GPU that is supported :) 

### usage 
- place ffmpeg tools in same folder as script 
- Update hevc_transcode_variables.ps1 variables in script then run hevc_transcode.ps1 in powershell 

### warning! 
**It will overwrite existing source files if conversion is successfull**

### functions
- traverses root path (scans all video files in subfolders) - as a job in background 
- transcodes video stream to hevc using **AMD or Nvidia GPU** (largest to smallest file) 
- transcodes video stream to hevc using CPU (smallest to largest file - in parallel) 
- copys all existing audio and subtitles (i.e. no conversion) 
- able to set min time before re-scanning media folder 
- overwrites source with new HEVC transcode if **move_file = 1** (WARNING this is default!) 
- checks to see if video codec is already HEVC (if so, skips)
- checks that HEVC conversion is successful (using video length) and is smaller than origanal file (99.9% of time this is true) - if larger does not overwrite and skips file 
- convert_1080p - if enabled will transcode larger resolutions down to 1080p HEVC 
- writes **transcode.log** for transcode attempts (duration and space savings) 
- writes **skip.log** for already hevc and failed transcodes (used to skip in next loop, errors in transcode.log) 
- writes **batch.log** for batch details 
- writes **scan_results.txt** 

### limitations (potential todo list) 
Deminishing effort vs reward - 
- does not change media container to mkv if source is another container format
- does not have a progress status during transcode 
