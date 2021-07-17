Set-Location $args[0]
$video = $args[1]
$job = $args[2]

Import-Module ".\functions.psm1" -Force

. .\hevc_transcode_variables.ps1
# Get-Variables

$run_start = (GET-Date)

#write-host "start-transcode" 

$video_path = $video.Fullname
$video_name = $video.name
$video_size = [math]::Round($video.length / 1GB, 2)

#Write-Host "Check if file is HEVC first..."
$video_codec = Get-VideoCodec $video_path

#check video width (1920 width is more consistant for 1080p videos)
$video_width = Get-VideoWidth $video_path

#check video duration $
$video_duration = Get-VideoDuration $video_path
$video_duration_formated = Get-VideoDurationFormatted $video_duration 

$start_time = (GET-Date)

#GPU Offload...
if ($convert_1080p -eq 1 -AND $video_width -gt 1920 ) { 
    Trace-Message "$job Job - $video_name (Codec: $video_codec, Width : $video_width, Size (GB): $video_size) Attempting transcode via $ffmpeg_codec to 1080p HEVC..."      
    Start-Sleep 1      
    .\ffmpeg.exe -hide_banner -xerror -v $ffmpeg_logging -y -i "$video_path" -vf scale=1920:-1 -map 0 -c:v $ffmpeg_codec -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 "output\$video_name"
}

elseif ($video_codec -ne "hevc") { 
    Trace-Message "$job Job - $video_name (Codec: $video_codec, Width : $video_width, Size (GB): $video_size) Attempting transcode via $ffmpeg_codec to HEVC..."            
    Start-Sleep 1
    .\ffmpeg.exe -hide_banner -xerror -v $ffmpeg_logging -y -i "$video_path" -map 0 -c:v $ffmpeg_codec -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 "output\$video_name"       
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

# Trace-Message "$job Job - $video_name ($run_time_current/$scan_period)"         


if (test-path -PathType leaf output\$video_name) {        

    #check size of new file 
    $video_new = Get-ChildItem output\$video_name | Select-Object Fullname, extension, length
    $video_new_size = [math]::Round($video_new.length / 1GB, 2)
    $diff = $video_size - $video_new_size
    $diff = [math]::Round($diff, 2)
    
    $diff_percent = [math]::Round((1 - ($video_new_size / $video_size)) * 100, 2)

    #check video length (used for progress updates)
    $video_new_duration = $null 
    $video_new_duration = (.\ffprobe.exe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1  "`"output\$video_name"`") | Out-String
    $video_new_duration = $video_new_duration.trim()
    $video_new_duration_formated = [timespan]::fromseconds($video_new_duration)
    $video_new_duration_formated = ("{0:hh\:mm\:ss}" -f $video_new_duration_formated)                

    # Trace-Message "$job Job - $video_name Transcode time: $start_time -> $end_time (duration: $total_time_formated)" 
    if ($video_width -gt 1920) { Trace-Message "  New Transcoded Video Width: $video_width -> 1920" }

    # Write-Host "$job Job - $video_name"
    if ($video_new_size -ne 0) {
        Trace-Message "$job Job - $video_name Transcode time : $total_time_formated, GB Saved : $diff ($video_size -> $video_new_size) or $diff_percent percent"
    }
                
    # check the file is healthy
    #confirm move file is enabled, and confirm file is 5% smaller or non-zero 
    #Write-Host "  DEBUG: old : $video_duration_formated new : $video_new_duration_formated"
    if ($move_file -eq 1 -AND $diff_percent -gt 5 -AND $diff_percent -lt 95 -AND $video_new_size -ne 0 -AND $diff -gt 0 -AND $video_duration_formated -eq $video_new_duration_formated) {    

        $delay = 5 
        $total_saved = $total_saved + $diff
        Write-Host -NoNewline "  Sleep before file move ($delay seconds)..."
        while ($delay -gt 0) {
                
            Write-Host -NoNewline "$delay..."
            Start-Sleep 1
            $delay = $delay - 1 

        }                                   
            
        Write-Host  -NoNewLine "0"                    
        Write-Host -NoNewline "  Overwriting original file " 
        write-host -NoNewline "(do not break or close window)" -ForegroundColor Yellow
        Write-host -NoNewline "..." 
        Move-item -Path "output\$video_name" -destination "$video_path" -Force
        Write-Host  " Done"

    }   

    else {
        
        if ($video_duration_formated -ne $video_new_duration_formated) { 
            Trace-Message "$job Job - $video_name incorrect duration on new video $video_new_duration_formated, File - NOT copied" 
            Remove-Item output\$video_name
        }
        elseif ($diff_percent -gt 95 -OR $diff_percent -lt 5 -OR $video_new_size -eq 0) { 
            Trace-Message "$job Job - $video_name file size change not within limits, File - NOT copied" 
            Remove-Item output\$video_name
        }
        elseif ($move_file -eq 0) { Trace-Message "$job Job - $video_name move file disabled, File - NOT copied" }
        else { Trace-Message "$job Job - $video_name File - NOT copied" }
        
    }         
        
    
}

Else {   
        
    if ($video_codec -eq "hevc") { Trace-Message  "$job Job - $video_name (Codec: $video_codec, Width : $video_width, Size (GB): $video_size) Skipped HEVC" }
    else { Trace-Message "$job Job - $video_name (Codec: $video_codec, Width : $video_width, Size (GB): $video_size) ERROR or FAILED" }        
                                    
}     
    
    
$count = $count + 1

if ($run_time_current -ne 0) { $gbpermin = $total_saved / $run_time_current }
else { $gbpermin = 0 }
$gbpermin = [math]::Round($gbpermin, 2)

# Update skip.txt with failed, hevc or already processed file 
Write-Output "$video_name" >> skip.log