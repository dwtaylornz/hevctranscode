# Variables - Update before run
# Paths 
$media_path = "Z:\videos\" # path in SMB share (must include trailing backslash) 

# Scanning 
$scan_at_start = 0 # wait for file scan to complete at start of script
$run_health_check = 0 # also run quick health check of videos 

# transcode and processing 
$ffmpeg_codec = "hevc_amf" # set to hevc_amf for AMD, hevc_nvenc for Nvidia, libx265 for CPU
$ffmpeg_hwdec = 0 # set to 1 if you want to decode via HW also 
$ffmpeg_logging = "error" # info, error, debug
$ffmpeg_timeout = 30 # timeout on job (minutes)
$ffmpeg_min_diff = .20 # must be at least this much smalller (percentage)
$ffmpeg_aac = 2 # 0 copies audio (no changes), set to 1 if you want to transcode audio to AAC (2 channel), 2 if you want to use libfdk_aac (2 channel, must be included in ffmpeg)
$ffmpeg_eng = 0 # set to 1 to only keep english audio tracks
$move_file = 1 # set to 0 for testing (check .\output directory) 
$convert_1080p = 1 # 1 will convert higher resolution videos down to 1080p , 0 will not
$min_video_size = .5 # min size in GB of video before it will quit
$GPU_threads = 2 # how many GPU jobs at same time 

# Write to influx
$influx_address = "http://192.168.9.10:9086"
$influx_db = "hevc"
