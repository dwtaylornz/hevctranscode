#check if file is HEVC first 
$video_codec = $null 
$video_codec = (./ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "`"$video_path"`") | Out-String
if (Select-String -pattern "hevc" -InputObject $video_codec -quiet) { $video_codec = "hevc" }
if (Select-String -pattern "h264" -InputObject $video_codec -quiet) { $video_codec = "h264" } 
if (Select-String -pattern "vc1" -InputObject $video_codec -quiet) { $video_codec = "vc1" }          
if (Select-String -pattern "mpeg2video" -InputObject $video_codec -quiet) { $video_codec = "mpeg2video" }
if (Select-String -pattern "mpeg4" -InputObject $video_codec -quiet) { $video_codec = "mpeg4" }

#check video width (1920 width is more consistant for 1080p videos)
$video_width = $null 
$video_width = (./ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
$video_width = $video_width.trim()
$video_width = $video_width -as [Int]

#check video length (used for progress updates)
$video_duration = $null 
$video_duration = (./ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
$video_duration = $video_duration.trim()
$video_duration_formated = [timespan]::fromseconds($video_duration)
$video_duration_formated = ("{0:hh\:mm\:ss}" -f $video_duration_formated)    

Write-Host ""
Write-Host "Processing : $video_name"
Write-Host "  Size (GB) : $video_size, Codec : $video_codec, Width : $video_width, Duration : $video_duration_formated"             

$start_time = (GET-Date)

$convert_error = 1 

#AMD Offload...
if ($convert_1080p -eq 1 -AND $video_width -gt 1920 -AND $hevc_offload -eq "AMD") { 
    Write-Host -NoNewline "  Attempting transcode via AMD to 1080p HEVC (started $start_time)..."            
    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -vf scale=1920:-1 -map 0 -c:v hevc_amf -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
    $convert_error = $LASTEXITCODE     

}

elseif ($video_codec -ne "hevc" -AND $hevc_offload -eq "AMD") { 
    Write-Host -NoNewline "  Attempting transcode via AMD to HEVC (started $start_time)..."            
    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -map 0 -c:v hevc_amf -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
    $convert_error = $LASTEXITCODE
                
}

#Nvidia Offload... 
elseif ($convert_1080p -eq 1 -AND $video_width -gt 1920 -AND $hevc_offload -eq "Nvidia") { 
    Write-Host -NoNewline "  Attempting transcode via Nvidia to 1080p HEVC (started $start_time)..."            
    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -vf scale=1920:-1 -map 0 -c:v hevc_nvenc -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
    $convert_error = $LASTEXITCODE     

}

elseif ($video_codec -ne "hevc" -AND $hevc_offload -eq "Nvidia") { 
    Write-Host -NoNewline "  Attempting transcode via Nvidia to HEVC (started $start_time)..."            
    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -map 0 -c:v hevc_nvenc -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
    $convert_error = $LASTEXITCODE
                
}

#CPU... (evaluated last) 
elseif ($convert_1080p -eq 1 -AND $video_width -gt 1920) { 
    Write-Host -NoNewline "  Attempting transcode via CPU to 1080p HEVC (started $start_time)..."            
    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -vf scale=1920:-1 -map 0 -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
    $convert_error = $LASTEXITCODE     

}

elseif ($video_codec -ne "hevc") { 
    Write-Host -NoNewline "  Attempting transcode via CPU to HEVC (started $start_time)..."            
    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -map 0 -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
    $convert_error = $LASTEXITCODE
                
}

            
$end_time = (GET-Date)

#calc time taken 
$time = $end_time - $start_time
$time_hours = $time.hours
$time_mins = $time.minutes
$time_secs = $time.seconds
$total_time_formated = "$time_hours" + ":" + "$time_mins" + ":" + "$time_secs" 
$run_time = $end_time - $run_start
$run_time_current = $run_time.minutes + ($run_time.hours * 60)

Write-Output "$video_name ($count/$file_count, $run_time_current/$scan_period)" >> transcode.log          
