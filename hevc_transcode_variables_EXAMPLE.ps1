# Variables EXAMPLE, please rename to hevc_transcode_variables.ps1

# Paths 
$ffmpeg_path = "C:\temp\ffmpeg\bin" # where ffmpeg lives
$media_path = "Z:\videos\" # path in SMB share (must include trailing backslash) 

# Scanning 
$scan_at_start = 0 # wait for scan files to complete at start of script

# transcode and processing 
$ffmpeg_codec = "hevc_nvenc" # set to hevc_amf for AMD, hevc_nvenc for Nvidia, libx265 for CPU
$move_file = 1 # set to 0 for testing (check .\output directory in ffmpeg_path) 
$ffmpeg_logging = "error" # info, error
$convert_1080p = 1 # 1 will convert higher resolution videos down to 1080p , 0 will not
$min_video_size = 0 # min size in GB of video before it will quit
$GPU_threads = 2 # how many GPU jobs at same time 

# SMB config
$smb_enabled = "true" # Set to true to map SMB drive
$smb_driveletter = "z:" # drive letter to map. Include colon. 
$smb_server = "server" # SMB server 
$smb_share = "share" # SMB share
$smb_user = "user" # SMB username
$smb_password = "password" # SMB password