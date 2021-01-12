
Set-Location $args[0]
$videos = $args[1]
$transcode_type = $args[2]

. .\hevc_transcode_variables.ps1

Foreach ($video in $videos) {

    $run_start = (GET-Date)

    if ((test-path -PathType leaf skip.log)) { 
        $skipped_files = Get-Content -Path skip.log 
        $skip_count = $skipped_files.Count
        }
    else { $skip_count = 0 }


        #check media drive still mappped
        while (!(test-path -PathType container $media_path) -AND $smb_enabled -eq "true") {
            Write-Host "Media drive lost : Attempting to reconnect to media share..."     
            net use $smb_driveletter \\$smb_server\$smb_share /user:$smb_user $smb_password | Out-Null
            Start-Sleep 10 
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

            #check if file is HEVC first 
            $video_codec = $null 
            $video_codec = (./ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "`"$video_path"`") | Out-String
            if (Select-String -pattern "hevc" -InputObject $video_codec -quiet) { $video_codec = "hevc" }
            if (Select-String -pattern "h264" -InputObject $video_codec -quiet) { $video_codec = "h264" } 
            if (Select-String -pattern "vc1" -InputObject $video_codec -quiet) { $video_codec = "vc1" }          
            if (Select-String -pattern "mpeg2video" -InputObject $video_codec -quiet) { $video_codec = "mpeg2video" }
            if (Select-String -pattern "mpeg4" -InputObject $video_codec -quiet) { $video_codec = "mpeg4" }
            if (Select-String -pattern "rawvideo" -InputObject $video_codec -quiet) { $video_codec = "rawvideo" }

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
            Write-Host "$transcode_type - $video_name"
            Write-Host "  Size (GB) : $video_size, Codec : $video_codec, Width : $video_width, Duration : $video_duration_formated" 

            # run background transcode
            #. .\job_hevc_transcode.ps1    
            
            $start_time = (GET-Date)
            $convert_error = 1 

            if ($transcode_type -eq "GPU"){
                #AMD Offload...
                if ($convert_1080p -eq 1 -AND $video_width -gt 1920 -AND $hevc_offload -eq "AMD") { 
                    Write-Host "  Attempting transcode via AMD to 1080p HEVC (started $start_time)"            
                    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -vf scale=1920:-1 -map 0 -c:v hevc_amf -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                    $convert_error = $LASTEXITCODE     

                }

                elseif ($video_codec -ne "hevc" -AND $hevc_offload -eq "AMD") { 
                    Write-Host "  Attempting transcode via AMD to HEVC (started $start_time)"            
                    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -map 0 -c:v hevc_amf -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                    $convert_error = $LASTEXITCODE
                
                }

                #Nvidia Offload... 
                elseif ($convert_1080p -eq 1 -AND $video_width -gt 1920 -AND $hevc_offload -eq "Nvidia") { 
                    Write-Host "  Attempting transcode via Nvidia to 1080p HEVC (started $start_time)"            
                    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -vf scale=1920:-1 -map 0 -c:v hevc_nvenc -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                    $convert_error = $LASTEXITCODE     

                }

                elseif ($video_codec -ne "hevc" -AND $hevc_offload -eq "Nvidia") { 
                    Write-Host "  Attempting transcode via Nvidia to HEVC (started $start_time)"            
                    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -map 0 -c:v hevc_nvenc -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                    $convert_error = $LASTEXITCODE
                
                }
            }

            elseif ($transcode_type -eq "CPU"){

                      #CPU... 
                if ($convert_1080p -eq 1 -AND $video_width -gt 1920) { 
                    Write-Host "  Attempting transcode via CPU to 1080p HEVC (started $start_time)"            
                    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -vf scale=1920:-1 -map 0 -c:v libx265 -x265-params log-level=error -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                    $convert_error = $LASTEXITCODE     

                }

                elseif ($video_codec -ne "hevc") { 
                    Write-Host "  Attempting transcode via CPU to HEVC (started $start_time)"            
                    ./ffmpeg -hide_banner -v $ffmpeg_logging -y -i $video_path -map 0 -c:v libx265 -x265-params log-level=error -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                    $convert_error = $LASTEXITCODE
                
                }

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

            Write-Output "$video_name ($run_time_current/$scan_period)" >> transcode.log           
       
       
            if (test-path -PathType leaf output\$video_name) {        

                #check size of new file 
                $video_new = Get-ChildItem output\$video_name | Select-Object Fullname, extension, length
                $video_new_size = [math]::Round($video_new.length / 1GB, 2)
                $diff = $video_size - $video_new_size
                $diff = [math]::Round($diff, 2)
                $total_saved = $total_saved + $diff
                $diff_percent = [math]::Round((1 - ($video_new_size / $video_size)) * 100, 2)

                #check video length (used for progress updates)
                $video_new_duration = $null 
                $video_new_duration = (./ffprobe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
                $video_new_duration = $video_new_duration.trim()
                $video_new_duration_formated = [timespan]::fromseconds($video_new_duration)
                $video_new_duration_formated = ("{0:hh\:mm\:ss}" -f $video_new_duration_formated)                

                Write-Output "  $transcode_type Transcode time: $start_time -> $end_time (duration: $total_time_formated)" >> transcode.log  
                if ($video_width -gt 1920) { Write-Output "  New Transcoded Video Width: $video_width -> 1920" >> transcode.log }
                if($diff -ne 0){Write-Output "  Video size (GB): $video_size -> $video_new_size (HEVC SAVED! $diff)" >> transcode.log}
                
                Write-Host "" 
                Write-Host "$transcode_type - $video_name TRANSCODE COMPLETE."
                Write-Host "  Duration : $total_time_formated, GB Saved : $diff ($video_size -> $video_new_size) or $diff_percent percent"
                       
                # check the file is healthy
                #confirm move file is enabled, and confirm file is 5% smaller or non-zero 
                #Write-Host "  DEBUG: old : $video_duration_formated new : $video_new_duration_formated"
                if ($move_file -eq 1 -AND $diff_percent -gt 5 -AND $diff_percent -lt 95 -AND $video_new_size -ne 0 -AND $diff -gt 0 -AND $video_duration_formated -eq $video_new_duration_formated) {    

                    $delay = 5 
                    Write-Host -NoNewline "  Sleep before copy ($delay seconds)..."
                    while ($delay -gt 0) {
                        
                        Write-Host -NoNewline "$delay..."
                        Start-Sleep 1
                        $delay = $delay - 1 

                    }                                   
                    
                    Write-Host  "0"                    
                    Write-Host -NoNewline "  Overwriting original file " 
                    write-host -NoNewline "(do not break or close window)" -ForegroundColor Yellow
                    Write-host -NoNewline "..." 
                    Move-item -Path "output\$video_name" -destination "$video_path" -Force
                    Write-Host  "Done"

                }   

                else {
                    Write-Host -NoNewline "  File - NOT copied"
                    if ($video_duration_formated -ne $video_new_duration_formated){Write-Host " (incorrect duration on new video)"}
                    elseif ($move_file -eq 0){Write-Host " (move file disabled)"}
                    elseif ($diff_percent -gt 95 -AND $diff_percent -lt 5 -AND $video_new_size -eq 0){Write-Host " (file size change not within limits)"}
                    else {Write-Host ""}
                    Write-Output "  File - NOT copied" >> transcode.log
                      if ($video_duration_formated -ne $video_new_duration_formated){Write-Host " (incorrect duration on new video)" >> transcode.log}
                    elseif ($move_file -eq 0){Write-Host " (move file disabled)" >> transcode.log}
                    elseif ($diff_percent -gt 95 -AND $diff_percent -lt 5 -AND $video_new_size -eq 0){Write-Host " (file size change not within limits)" >> transcode.log}
                    else {Write-Host "" >> transcode.log}
                }         
                
            }

            Else {   
                
                if ($video_codec -eq "hevc") {
                    Write-Host "  HEVC skipped" 
                    Write-Output "  SKIPPED, (Codec: $video_codec, Width : $video_width, Size (GB): $video_size)" >> transcode.log
                }
                else {
                    Write-Host "  ERROR or FAILED" 
                    Write-Output "  ERROR or FAILED, (Codec: $video_codec, Width : $video_width, Size (GB): $video_size)" >> transcode.log
                }        
                                          
            }     
            
            
            $count = $count + 1
            Write-Host "$transcode_type Batch : Time : $run_time_current/$scan_period, Total GB Saved: $total_saved " 
            # Write-Output "Batch : Time : $run_time_current/$scan_period, Total GB Saved: $total_saved " >> batch.log

            # Update skip.txt with failed, hevc or already processed file 
            Write-Output "$video_name" >> skip.log
            
            if ($run_time_current -ge $scan_period) { break }
          
        }      

    }
              