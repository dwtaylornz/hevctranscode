# Get largest files

Set-Location $args[0]

# grab variables from var file 
. .\hevc_transcode_variables.ps1

#Write-Host -NoNewline "Checking all video files and sizes (sorting largest to smallest)..." 
$videos = Get-ChildItem -r $media_path -Include *.mkv, *.avi, *.mp4, *.ts, *.mov, *.y4m, *.m2ts | Sort-Object -descending -Property length | Select-Object Fullname, name, length
#$file_count = $videos.Count
$videos | Export-Csv ./scan_results.csv

#Write-Host "Done ($file_count)" 
#Remove-Job -Name Scan -ea silentlycontinue