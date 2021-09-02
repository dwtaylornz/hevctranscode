# Variables - Update before run

# Paths 
$media_path = "Z:\videos\" # path in SMB share (must include trailing backslash) 

# Scanning 
$scan_at_start = 0 # wait for scan files to complete at start of script
$run_health_check = 0 # also run quick health check of videos 

# transcode and processing 
$ffmpeg_codec = "hevc_nvenc" # set to hevc_amf for AMD, hevc_nvenc for Nvidia, libx265 for CPU
$ffmpeg_hwdec = 0 # set to 1 if you want to decode via HW also 
$ffmpeg_logging = "error" # info, error
$move_file = 1 # set to 0 for testing (check .\output directory) 
$convert_1080p = 1 # 1 will convert higher resolution videos down to 1080p , 0 will not
$min_video_size = 0.3 # min size in GB of video before it will quit
$GPU_threads = 2 # how many GPU jobs at same time 