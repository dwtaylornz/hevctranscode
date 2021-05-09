# Variables 

# Paths 
$ffmpeg_path = "C:\temp\ffmpeg\bin" # where ffmpeg lives
$media_path = "Z:\videos\" # path in SMB share (must include trailing backslash) 

# Scanning 
$scan_at_start = 0 # wait for scan files to complete at start of script
$scan_period = "1440" # max minutes before doing a re-scan

# transcode and processing 
$ffmpeg_codec = "hevc_nvenc" # set to hevc_amf for AMD, hevc_nvenc for Nvidia, libx265 for CPU
$move_file = 0 # set to 0 for testing (check .\output directory in ffmpeg_path) 
$ffmpeg_logging = "error" # info, error
$convert_1080p = 1 # 1 will convert higher resolution videos down to 1080p , 0 will not
$disable_parallel_cpu_transcode = 1 # set to 1 to disable parallel cpu transcoding (EXPERIMENTAL) 

# SMB config
$smb_enabled = "true" # Set to true to map SMB drive
$smb_driveletter = "z:" # drive letter to map. Include colon. 
$smb_server = "lexx" # SMB server 
$smb_share = "videos" # SMB share
$smb_user = "darren" # SMB username
$smb_password = "Hithere01" # SMB password