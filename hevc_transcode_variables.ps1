# Variables 
$scan_at_start = 1 # scan files at start of script
$scan_period = "1440" # max minutes before doing a re-scan
$move_file = 1 # set to 0 for testing
$hevc_offload = "AMD" # set to AMD, NVIDIA or CPU
$ffmpeg_logging = "error" # info, error
$convert_1080p = 0 # 1 will convert higher resolution videos down to 1080p , 0 will not
$video_directory = "z:\videos\" # path in SMB share 
$ffmpeg_path = "C:\temp\ffmpeg\bin" # where ffmpeg lives

# If useing SMB it'll be mapped to z: drive 
$smb_enabled = "true" # Set to true to map SMB drive
$smb_driveletter = "z:" # drive letter to map. Include colon. 
$smb_server = "server" # SMB server 
$smb_share = "share" # SMB share
$smb_user = "user" # SMB username
$smb_password = "password" # SMB password

# todo 
# progress update on transcoding 
# convert to mkv? 