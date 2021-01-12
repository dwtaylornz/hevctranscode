# Variables 

# Paths 
$ffmpeg_path = "C:\temp\ffmpeg\bin" # where ffmpeg lives
$media_path = "Z:\videos\" # path in SMB share (must include trailing backslash) 

# Scanning 
$scan_at_start = 0 # scan files at start of script
$scan_period = "240" # max minutes before doing a re-scan

# transcode and processing 
$hevc_offload = "AMD" # set to AMD or NVIDIA
$move_file = 1 # set to 0 for testing (check .\output directory in ffmpeg_path) 
$ffmpeg_logging = "error" # info, error
$convert_1080p = 1 # 1 will convert higher resolution videos down to 1080p , 0 will not
$disable_parallel_cpu_transcode = 0 # set to 1 to disable parallel cpu transcoding 

# If useing SMB it'll be mapped to z: drive 
$smb_enabled = "true" # Set to true to map SMB drive
$smb_driveletter = "z:" # drive letter to map. Include colon. 
$smb_server = "server" # SMB server 
$smb_share = "share" # SMB share
$smb_user = "user" # SMB username
$smb_password = "password" # SMB password
