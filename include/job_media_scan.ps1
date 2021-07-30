<<<<<<< HEAD:include/job_media_scan.ps1
﻿# set root directory
Set-Location $args[0]

# grab variables from var file 
. .\hevc_transcode_variables.ps1

#Write-Host -NoNewline "Checking all video files and sizes (sorting largest to smallest)..." 
$videos = Get-ChildItem -r $media_path -Include *.mkv, *.avi, *.mp4, *.ts, *.mov, *.y4m, *.m2ts | Sort-Object -descending -Property length | Select-Object Fullname, name, length
$videos | Export-Csv ./scan_results.csv -Encoding utf8
=======
﻿# set root directory
Set-Location $args[0]

# grab variables from var file 
. .\hevc_transcode_variables.ps1

#Write-Host -NoNewline "Checking all video files and sizes (sorting largest to smallest)..." 
$videos = Get-ChildItem -r $media_path -Include *.mkv, *.avi, *.mp4, *.ts, *.mov, *.y4m, *.m2ts | Sort-Object -descending -Property length | Select-Object Fullname, name, length
$videos | Export-Csv ./scan_results.csv
>>>>>>> 646586e567f557bc6075a2e7f57e812b0f3b0501:job_media_scan.ps1
