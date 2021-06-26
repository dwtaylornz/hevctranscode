
Set-Location $args[0]
$videos = $args[1]
$job = $args[2]
$total_saved = 0

Import-Module ".\functions.psm1" -Force

. .\hevc_transcode_variables.ps1
# Get-Variables

$run_start = (GET-Date)

#write-host "start-transcode" 

Foreach ($video in $videos) {

    if ((test-path -PathType leaf skip.log)) { 
        $skipped_files = Get-Content -Path skip.log 
    }

    $video_path = $video.Fullname
    $video_name = $video.name
    $video_size = [math]::Round($video.length / 1GB, 2)

    #check if file is in skip list 
    $skip = 0 
    Foreach ($skipped_file in $skipped_files) {
        if ($skipped_file -eq $video_name) {
            $skip = 1
            break
        }  
    }

    if ($skip -eq 0) {   

        #Write-Host "Check if file is HEVC first..."
        $video_codec = $null 
        $video_codec = (.\ffprobe.exe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "`"$video_path"`") | Out-String
        if (Select-String -pattern "hevc" -InputObject $video_codec -quiet) { $video_codec = "hevc" }
        if (Select-String -pattern "h264" -InputObject $video_codec -quiet) { $video_codec = "h264" } 
        if (Select-String -pattern "vc1" -InputObject $video_codec -quiet) { $video_codec = "vc1" }          
        if (Select-String -pattern "mpeg2video" -InputObject $video_codec -quiet) { $video_codec = "mpeg2video" }
        if (Select-String -pattern "mpeg4" -InputObject $video_codec -quiet) { $video_codec = "mpeg4" }
        if (Select-String -pattern "rawvideo" -InputObject $video_codec -quiet) { $video_codec = "rawvideo" }

        #check video width (1920 width is more consistant for 1080p videos)
        $video_width = $null 
        $video_width = (.\ffprobe.exe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
        $video_width = $video_width.trim()
        $video_width = $video_width -as [Int]

        #check video length
        $video_duration = $null 
        $video_duration = (.\ffprobe.exe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
        $video_duration = $video_duration.trim()
        $video_duration_formated = [timespan]::fromseconds($video_duration)
        $video_duration_formated = ("{0:hh\:mm\:ss}" -f $video_duration_formated)    

        # Write-Host ""
        # Write-Host -nonewline "$job Job - $video_name"
        # Write-Host "  Size (GB) : $video_size, Codec : $video_codec, Width : $video_width, Length : $video_duration_formated" 

        # run background transcode
        #. .\job_hevc_transcode.ps1    
            
        $start_time = (GET-Date)
        # $convert_error = 1 
   
        #GPU Offload...
        if ($convert_1080p -eq 1 -AND $video_width -gt 1920 -AND $job -ne "CPU") { 
            Trace-Message "$job Job - $video_name Attempting transcode via $ffmpeg_codec to 1080p HEVC"      
            Start-Sleep 5      
            .\ffmpeg.exe -hide_banner -v $ffmpeg_logging -y -i "$video_path" -vf scale=1920:-1 -map 0 -c:v $ffmpeg_codec -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 "output\$video_name"
            #$convert_error = $LASTEXITCODE     

        }

        elseif ($video_codec -ne "hevc" -AND $job -ne "CPU") { 
            Trace-Message "$job Job - $video_name Attempting transcode via $ffmpeg_codec to HEVC"            
            Start-Sleep 5
            .\ffmpeg.exe -hide_banner -v $ffmpeg_logging -y -i "$video_path" -map 0 -c:v $ffmpeg_codec -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 "output\$video_name"
            #$convert_error = $LASTEXITCODE
                
        }
        
        #CPU...
        elseif ($convert_1080p -eq 1 -AND $video_width -gt 1920) { 
            Trace-Message "$job Job - $video_name Attempting transcode via libx265 to 1080p HEVC"            
            .\ffmpeg.exe -hide_banner -v $ffmpeg_logging -y -i "$video_path" -vf scale=1920:-1 -map 0 -c:v -x265-params log-level=error -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 "output\$video_name"
            #$convert_error = $LASTEXITCODE     
                
        }

        elseif ($video_codec -ne "hevc") { 
            Trace-Message "$job Job - $video_name Attempting transcode via libx265 to HEVC"            
            .\ffmpeg.exe -hide_banner -v $ffmpeg_logging -y -i "$video_path" -map 0 -c:v libx265 -x265-params log-level=error -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 "output\$video_name"
            #$convert_error = $LASTEXITCODE
                
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

        Trace-Message "$job Job - $video_name ($run_time_current/$scan_period)"         
       
       
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

            Trace-Message "$job Job - $video_name Transcode time: $start_time -> $end_time (duration: $total_time_formated)" 
            if ($video_width -gt 1920) { Write-Output "  New Transcoded Video Width: $video_width -> 1920" >> transcode.log }
            if ($diff -ne 0) { Write-Output "  Video size (GB): $video_size -> $video_new_size (HEVC SAVED! $diff)" >> transcode.log }
                
            # Write-Host "" 
            # Write-Host "$job Job - $video_name"
            if ($video_new_size -ne 0){
                Trace-Message "$job Job - $video_name  Transcode time : $total_time_formated, GB Saved : $diff ($video_size -> $video_new_size) or $diff_percent percent"
                }
                       
            # check the file is healthy
            #confirm move file is enabled, and confirm file is 5% smaller or non-zero 
            #Write-Host "  DEBUG: old : $video_duration_formated new : $video_new_duration_formated"
            if ($move_file -eq 1 -AND $diff_percent -gt 5 -AND $diff_percent -lt 95 -AND $video_new_size -ne 0 -AND $diff -gt 0 -AND $video_duration_formated -eq $video_new_duration_formated) {    

                $delay = 5 
                $total_saved = $total_saved + $diff
                Write-Host -NoNewline "  Sleep before copy ($delay seconds)..."
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
                    
                Write-Host -NoNewline "  File - NOT copied"
                if ($video_duration_formated -ne $video_new_duration_formated) { 
                    Write-Host -NoNewline " (incorrect duration on new video)" 
                   # Remove-Item output\$video_name | Out-Null
                }
                if ($diff_percent -gt 95 -OR $diff_percent -lt 5 -OR $video_new_size -eq 0) { 
                    Write-Host -NoNewline " (file size change not within limits)" 
                   # Remove-Item output\$video_name | Out-Null
                }
                if ($move_file -eq 0) { Write-Host -NoNewline " (move file disabled)" }
                Write-Host ""

                Write-Output "  File - NOT copied" >> transcode.log
                if ($video_duration_formated -ne $video_new_duration_formated) { Write-Output "  (incorrect duration on new video $video_new_duration_formated)" >> transcode.log }
                if ($diff_percent -gt 95 -OR $diff_percent -lt 5 -OR $video_new_size -eq 0) { Write-Output "  (file size change not within limits)" >> transcode.log }
                if ($move_file -eq 0) { Write-Output -NoNewline" (move file disabled)" >> transcode.log }
                    
            }         
                
        }

        Else {   
                
            if ($video_codec -eq "hevc") {
                Write-Host "  Already HEVC, skipped" 
                Trace-Message  "$job Job - $video_name SKIPPED, (Codec: $video_codec, Width : $video_width, Size (GB): $video_size)" 
            }
            else {
                Write-Host "  ERROR or FAILED" 
                Trace-Message "$job Job - $video_name ERROR or FAILED, (Codec: $video_codec, Width : $video_width, Size (GB): $video_size)" 
            }        
                                          
        }     
            
            
        $count = $count + 1

        if ($run_time_current -ne 0) { $gbpermin = $total_saved / $run_time_current }
        else { $gbpermin = 0 }
        $gbpermin = [math]::Round($gbpermin, 2)
        #Write-Host "  Batch Time : $run_time_current/$scan_period, Total GB Saved: $total_saved, GB/min : $gbpermin " 
        #Write-Output "Batch : $run_start Time : $run_time_current/$scan_period, Total GB Saved: $total_saved, GB/min : $gbpermin  " >> batch.log

        # Update skip.txt with failed, hevc or already processed file 
        Write-Output "$video_name" >> skip.log
            
        if ($run_time_current -ge $scan_period) { break }
          
    }      

}
              