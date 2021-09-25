Set-Location $args[0]
$video = $args[1]
$job = $args[2]

Import-Module ".\include\functions.psm1" -Force

# Get-Variables
. .\variables.ps1

#write-host "start-transcode" 
$video_name = $video.name
$video_path = $video.Fullname
$video_size = [math]::Round($video.length / 1GB, 1)

#Add to skip file so it is not processed again 
Write-Skip $video_name

#Write-Host "Check if file is HEVC first..."
$video_codec = Get-VideoCodec $video_path

#check video width (1920 width is more consistant for 1080p videos)
$video_width = Get-VideoWidth $video_path

#check video duration 
$video_duration = Get-VideoDuration $video_path
$video_duration_formated = Get-VideoDurationFormatted $video_duration 

$start_time = (GET-Date)

# NVIDIA TUNING - disable NVDEC 
#if ($ffmpeg_codec -eq "hevc_nvenc"){$ffmpeg_codec_tune = "-pix_fmt yuv420p10le -b:v 0 -rc:v vbr"}

if ($ffmpeg_hwdec -eq 1) { $ffmpeg_dec_cmd = "-hwaccel cuda -hwaccel_output_format cuda" }
if ($ffmpeg_hwdec -eq 0) { $ffmpeg_dec_cmd = $null }
if ($convert_1080p -eq 1 -AND $video_width -gt 1920) { $ffmpeg_cmd_scale = "-vf scale=1920:-1" } 
if ($convert_1080p -eq 0) { $ffmpeg_cmd_scale = $null } 

# Main FFMPEG Params 
$ffmpeg_params = ".\ffmpeg.exe -hide_banner -xerror -v $ffmpeg_logging -y $ffmpeg_dec_cmd -i ""$video_path"" $ffmpeg_cmd_scale -map 0 -c:v $ffmpeg_codec $ffmpeg_codec_tune -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 ""output\$video_name"""

#GPU Offload...
if ($video_codec -ne "hevc") { 
    Trace-Message "$job - $video_name ($video_codec, $video_width, $video_size`GB`) transcoding via $ffmpeg_codec..."            
    Start-Sleep 1
    Invoke-Expression $ffmpeg_params -ErrorVariable err 
    If ($err -ne "") { 
        Trace-Error "$job - $video_name $err" 

}
}

$end_time = (GET-Date)

#calc time taken 
$time = $end_time - $start_time
$time_hours = $time.hours
$time_mins = $time.minutes
$time_secs = $time.seconds 
if ($time_secs -lt 10) { $time_secs = "0$time_secs" }
$total_time_formatted = "$time_hours" + ":" + "$time_mins" + ":" + "$time_secs" 
if ($time_hours -eq 0) { $total_time_formatted = "$time_mins" + ":" + "$time_secs" }

# Trace-Message "$job Job - $video_name ($run_time_current/$scan_period)"         

if (test-path -PathType leaf output\$video_name) {        

    #check size of new file 
    $video_new = Get-ChildItem output\$video_name | Select-Object Fullname, extension, length
    $video_new_size = [math]::Round($video_new.length / 1GB, 1)
    $diff = $video_size - $video_new_size
    $diff = [math]::Round($diff, 1)
    
    $diff_percent = [math]::Round((1 - ($video_new_size / $video_size)) * 100, 0)

    #check video length (used for progress updates)
    $video_new_duration = $null 

    $video_new_duration = Get-VideoDuration "output\$video_name"
    $video_new_duration_formated = Get-VideoDurationFormatted $video_new_duration
                 
    # Trace-Message "$job Job - $video_name Transcode time: $start_time -> $end_time (duration: $total_time_formatted)" 
    if ($video_width -gt 1920) { Trace-Message "  New Transcoded Video Width: $video_width -> 1920" }
              
    # check the file is healthy
    #confirm move file is enabled, and confirm file is 5% smaller or non-zero 
    #Write-Host "  DEBUG: old : $video_duration_formated new : $video_new_duration_formated"
    if ($move_file -eq 1 -AND $diff_percent -gt 5 -AND $diff_percent -lt 95 -AND $video_new_size -ne 0 -AND $diff -gt 0 -AND $video_duration_formated -eq $video_new_duration_formated) {    

        Trace-Message "$job - $video_name Transcode time: $total_time_formatted, Saved: $diff`GB` ($video_size -> $video_new_size) or $diff_percent%"
        Start-delay

        try {
            Move-item -Path "output\$video_name" -destination "$video_path" -Force 
            Trace-Savings "$job - $video_name Transcode time: $total_time_formatted, Saved: $diff`GB` ($video_size -> $video_new_size) or $diff_percent%"
        }
        catch {
            Trace-Message "Error moving $video_name back to source location - Check permissions"
            Trace-Error $_.exception.message 
    
        }
    }   

    else {
        
        if ($video_duration_formated -ne $video_new_duration_formated) { 
            Trace-Message "$job - $video_name incorrect duration on new video ($video_duration_formated -> $video_new_duration_formated), File - NOT copied" 
            Start-Sleep 2
            Remove-Item output\$video_name
        }
        elseif ($diff_percent -gt 95 -OR $diff_percent -lt 5 -OR $video_new_size -eq 0) { 
            Trace-Message "$job - $video_name file size change not within limits, File - NOT copied" 
            Start-Sleep 2
            Remove-Item output\$video_name
        }
        elseif ($move_file -eq 0) { Trace-Message "$job - $video_name move file disabled, File - NOT copied" }
        else { Trace-Message "$job - $video_name File - NOT copied" }
        Write-SkipError $video_name
    }            
}

Else {   
    if ($video_codec -eq "hevc") {
        Trace-Message  "$job - $video_name ($video_codec, $video_width, $video_size GB) Already HEVC, Skipping" 
        Write-SkipHEVC $video_name

        
    }
    else { Trace-Message "$job - $video_name ($video_codec, $video_width, $video_size GB) ERROR or FAILED" }                                
}     
