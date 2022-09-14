Set-Location $args[0]
$video = $args[1]
$job = $args[2]

Import-Module ".\include\functions.psm1" -Force

$RootDir = $PSScriptRoot
if ($RootDir -eq "") {
    $RootDir = $pwd
}

# Get-Variables
. (Join-Path $RootDir variables.ps1)

# write-host "start-transcode" 
$video_name = $video.name
$video_path = $video.Fullname
$video_size = [math]::Round($video.length / 1GB, 1)

# Write-Host "Check if file is HEVC first..."
$video_codec = Get-VideoCodec $video_path

# check video width (1920 width is more consistant for 1080p videos)
$video_width = Get-VideoWidth $video_path

# check video duration 
$video_duration = Get-VideoDuration $video_path
$video_duration_formated = Get-VideoDurationFormatted $video_duration 

$start_time = (GET-Date)

# Add to skip file so it is not processed again
# do at beginning so that stuff that times out does not get processed again. 
Write-Skip $video_name

# NVIDIA TUNING -
# if ($ffmpeg_codec -eq "hevc_nvenc"){$ffmpeg_codec_tune = "-pix_fmt yuv420p10le -b:v 0 -rc:v vbr"}
# AMD TUNING - 
if ($ffmpeg_codec -eq "hevc_amf") { $ffmpeg_codec_tune = "-usage transcoding -quality quality -header_insertion_mode idr" }

if ($ffmpeg_hwdec -eq 1) { $ffmpeg_dec_cmd = "-hwaccel cuda -hwaccel_output_format cuda" }
if ($ffmpeg_hwdec -eq 0) { $ffmpeg_dec_cmd = $null }

if ($ffmpeg_aac -eq 1) { $ffmpeg_aac_cmd = "aac" }
if ($ffmpeg_aac -eq 0) { $ffmpeg_aac_cmd = "copy" }

if ($convert_1080p -eq 1 -AND $video_width -gt 1920) { $ffmpeg_scale_cmd = "-vf scale=1920:-1" } 
if ($convert_1080p -eq 0) { $ffmpeg_scale_cmd = $null } 

# check path 
# Test-VideoPath "$video_path"

# Main FFMPEG Params 
$ffmpeg_params = ".\ffmpeg.exe -hide_banner -xerror -v $ffmpeg_logging -y $ffmpeg_dec_cmd -i ""$video_path"" $ffmpeg_scale_cmd -map 0 -c:v $ffmpeg_codec $ffmpeg_codec_tune -c:a $ffmpeg_aac_cmd -c:s copy -err_detect explode -max_muxing_queue_size 9999 ""output\$video_name"""

# GPU Offload...
if ($video_codec -ne "hevc" ) {
    Write-Log "$job - $video_name ($video_codec, $video_width, $video_size`GB`) transcoding..."            
    Start-Sleep 1
    Invoke-Expression $ffmpeg_params -ErrorVariable err 

    if ($err) {
        Write-Log "$job - $video_name $err"
    }

    $end_time = (GET-Date)

    # calc time taken 
    $time = $end_time - $start_time
    $time_hours = $time.hours
    $time_mins = $time.minutes
    $time_secs = $time.seconds 
    if ($time_secs -lt 10) { $time_secs = "0$time_secs" }
    $total_time_formatted = "$time_hours" + ":" + "$time_mins" + ":" + "$time_secs" 
    if ($time_hours -eq 0) { $total_time_formatted = "$time_mins" + ":" + "$time_secs" }

    # Write-Log "$job Job - $video_name ($run_time_current/$scan_period)"         
}

if (test-path -PathType leaf output\$video_name) {        

    # check size of new file 
    $video_new = Get-ChildItem output\$video_name | Select-Object Fullname, extension, length
    $video_new_size = [math]::Round($video_new.length / 1GB, 1)
    $diff = $video_size - $video_new_size
    $diff = [math]::Round($diff, 1)
    
    $diff_percent = [math]::Round((1 - ($video_new_size / $video_size)) * 100, 0)

    # check video length (used for progress updates)
    $video_new_duration = $null 
    $video_new_duration = Get-VideoDuration output\$video_name
    $video_new_duration_formated = Get-VideoDurationFormatted $video_new_duration
                 
    # Write-Log "$job Job - $video_name Transcode time: $start_time -> $end_time (duration: $total_time_formatted)" 
    if ($video_width -gt 1920) { Write-Log "  New Transcoded Video Width: $video_width -> 1920" }
              
    # check the file is healthy
    # confirm move file is enabled, and confirm file is 10% smaller or non-zero 
    # Write-Host "  DEBUG: old : $video_duration_formated new : $video_new_duration_formated"
    if ($move_file -eq 1 -AND $diff_percent -gt 10 -AND $diff_percent -lt 90 -AND $video_new_size -ne 0 -AND $diff -gt 0 -AND $video_duration_formated -eq $video_new_duration_formated) {    

        Write-Log "$job - $video_name Transcode time: $total_time_formatted, Saved: $diff`GB` ($video_size -> $video_new_size) or $diff_percent%"
        if ($influx_address -AND $influx_db) {
            Invoke-WebRequest "$influx_address/write?db=$influx_db" -Method POST -Body "gb_saved value=$diff" | Out-Null 
        } 
        Start-delay

        try {
            Move-item -Path "output\$video_name" -destination "$video_path" -Force 
            Write-SkipHEVC $video_name
        }
        catch {
            Write-Log "Error moving $video_name back to source location - Check permissions"
            Write-Log $_.exception.message 
        }
    }   

    else {
        
        if ($video_duration_formated -ne $video_new_duration_formated) { 
            Write-Log "$job - $video_name incorrect duration on new video ($video_duration_formated -> $video_new_duration_formated), File - NOT copied" 
        }
        elseif ($diff_percent -gt 95 -OR $diff_percent -lt 5 -OR $video_new_size -eq 0) { 
            Write-Log "$job - $video_name file size change not within limits, File - NOT copied" 
        }
        elseif ($move_file -eq 0) { 
            Write-Log "$job - $video_name move file disabled, File - NOT copied" 
        }
        else { 
            Write-Log "$job - $video_name File - NOT copied" 
        }
        Write-SkipError $video_name
        Start-sleep 1
        Remove-Item output\$video_name
    }            
}

Else {   
    if ($video_codec -eq "hevc") {
        Write-Log  "$job - $video_name ($video_codec, $video_width, $video_size GB) Already HEVC, Skipping" 
        Write-SkipHEVC $video_name
    }
    else { 
        Write-Log "$job - $video_name ($video_codec, $video_width, $video_size GB) ERROR or FAILED" 
        # Write-Skip $video_name
    }                                
}     