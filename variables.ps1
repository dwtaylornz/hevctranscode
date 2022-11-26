# Variables - Update before run
# Paths 
$media_path = "Z:\videos\" # path to videos (if smb, must include trailing backslash) 
$log_path = "$PWD" # path to logs and skip files

# Scanning 
$scan_at_start = 0 # 0 = get previous results and run background scan, 1 = force scan and wait for results, 2 = get results, no scan 
$run_health_check = 0 # also run quick health check of videos 
$restart_queue = 120 # mins before re-doing the scan and start going through the queue again

# transcode and processing 
$ffmpeg_codec = "hevc_amf" # set to hevc_amf for AMD, hevc_nvenc for Nvidia, libx265 for CPU
$ffmpeg_hwdec = 0 # set to 1 if you want to decode via HW also 
$ffmpeg_logging = "quiet" # "quiet", "panic", "fatal", "error", "warning", "info", "verbose", "debug", "trace"
$ffmpeg_timeout = 120 # timeout on job (minutes)
$ffmpeg_min_diff = 20 # must be at least this much smalller (percentage)
$ffmpeg_max_diff = 95 # must be at most this much bigger (percentage)
$ffmpeg_aac = 2 # 0 copies audio (no changes), set to 1 if you want to transcode audio to AAC (2 channel), 2 if you want to use libfdk_aac (2 channel, must be included in ffmpeg)
$ffmpeg_mp4 = 0 # set to 1 to convert to mp4 
$ffmpeg_eng = 0 # set to 1 to only keep english audio tracks
$ffmpeg_crf = # 22 (28 default)
$move_file = 1 # set to 0 for testing (check .\output directory) 
$convert_1080p = 1 # 1 will convert higher resolution videos down to 1080p , 0 will not
$min_video_size = 0 # min size in GB of video before it will quit
$GPU_threads = 2 # how many GPU jobs at same time 

# used to fix color headers for roku playback (must have mkvpropedit.exe)
$mkv_color_fix = 1

# Write to influx
$influx_address = "http://192.168.9.10:9086"
$influx_db = "hevc"

# TODO

# $host.privatedata.ProgressForegroundColor = "gray";
# $host.privatedata.ProgressBackgroundColor = "black";

# for($I = 0; $I -lt 10; $I++ ) {
#     $OuterLoopProgressParameters = @{
#         Activity         = 'Updating'
#         Status           = 'Progress->'
#         PercentComplete  = $I * 10
#         CurrentOperation = 'OuterLoop'
#     }
#     Write-Progress @OuterLoopProgressParameters
#     for($j = 1; $j -lt 101; $j++ ) {
#         $InnerLoopProgressParameters = @{
#             ID               = 1
#             Activity         = 'Updating'
#             Status           = 'Progress'
#             PercentComplete  = $j
#             CurrentOperation = 'InnerLoop'
#         }
#         Write-Progress @InnerLoopProgressParameters
#         Start-Sleep -Milliseconds 25
#     }
# }