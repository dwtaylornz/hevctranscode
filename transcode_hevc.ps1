# powershell 
# github.com/dwtaylornz/hevcamdwin
#
# script will continously loop - batch size only used to control how often disk is scanned for new media

# Variables 
$scan_period = "240" # max minutes before doing a re-scan
$batch_size = "1000" # max batch size before doing a re-scan 
$move_file = 1 # set to 0 for testing
$hevc_offload = "AMD" # set to AMD, NVIDIA or CPU
$hevc_quality = "5" # For AMD, 0-10 (highest - lowest) 
$hevc_verbose = "error" # info, error
$convert_1080p = 1 # 1 will convert higher resolution videos down to 1080p , 0 will not
$video_directory = "z:\videos" # path in SMB share 
$ffmpeg_path = "C:\temp\ffmpeg\bin" # where ffmpeg lives

# If useing SMB it'll be mapped to z: drive 
$smb_server = "servername or ip" # SMB server 
$smb_share = "share" # SMB share
$smb_user = "user" # SMB username
$smb_password = "password" # SMB password

cd $ffmpeg_path

#map media drive 
while (!(test-path -PathType container $video_directory)) {
    sleep 2
    Write-Host -NoNewline "Mapping Drive (assuming smb)... "     
    net use z: \\$smb_server\$smb_share /user:$smb_user $smb_password | Out-Null   
}

# Setup temp output folder, and clear previous transcodes
if (!(test-path -PathType container output)) { new-item -itemtype directory -force -path output | Out-Null }
# else {rm output\*.*}

# Main 
while ($true) {
    
    # Get largest files
    Write-Host ""
    Write-Host -NoNewline "Checking all files and sizes (sorting largest to smallest)..." 
    $videos = gci -r $video_directory | sort -descending -Property length | select Fullname, name, length
    Write-Host "Done" 

    # Get previously skipped files
    Write-Host -NoNewline "Getting previously skipped or completed files..." 
    if ((test-path -PathType leaf skip.log)) { $skipped_files = Get-Content -Path skip.log }
    Write-Host "Done" 
    
    $count = 1 
    $run_start = (GET-Date)
      
    # For Each video 
    Foreach ($video in $videos) {

        #check media drive still mappped
        while (!(test-path -PathType container $video_directory)) {
            Write-Host "Media drive lost : Attempting to reconnect to media share..."     
            net use z: \\$smb_server\$smb_share /user:$smb_user $smb_password | Out-Null
            sleep 10 
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
            if (Select-String -pattern "hevc" -InputObject $video_codec -quiet){$video_codec = "hevc"}
            if (Select-String -pattern "h264" -InputObject $video_codec -quiet){$video_codec = "h264"} 
            if (Select-String -pattern "vc1" -InputObject $video_codec -quiet){$video_codec = "vc1"}          
            if (Select-String -pattern "mpeg2video" -InputObject $video_codec -quiet){$video_codec = "mpeg2video"}

            #check video width (1920 width is more consistant for 1080p videos)
            $video_width = $null 
            $video_width = (./ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
            $video_width = $video_width.trim()
            $video_width = $video_width.substring(0, 4)

            Write-Host ""
            Write-Host "Processing : $video_name"
            Write-Host "  Size (GB) : $video_size, Video Codec : $video_codec, Video Width : $video_width"
                

            $start_time = (GET-Date)

            $convert_error = 1 

            #AMD Offload...
            if ($convert_1080p -eq 1 -AND $video_width -gt 1920 -AND $hevc_offload -eq "AMD") { 
                Write-Host -NoNewline "  Attempting transcode via AMD to 1080p HEVC (this may take some time)..."            
                ./ffmpeg -hide_banner -v $hevc_verbose -y -i $video_path -vf scale=1920:-1 -map 0 -c:v hevc_amf -quality $hevc_quality -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                $convert_error = $LASTEXITCODE     

            }

            elseif ($video_codec -ne "hevc" -AND $hevc_offload -eq "AMD") { 
                Write-Host -NoNewline "  Attempting transcode via AMD to HEVC (this may take some time)..."            
                ./ffmpeg -hide_banner -v $hevc_verbose -y -i $video_path -map 0 -c:v hevc_amf -quality $hevc_quality -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                $convert_error = $LASTEXITCODE
                
            }

            #Nvidia Offload... 
            elseif ($convert_1080p -eq 1 -AND $video_width -gt 1920 -AND $hevc_offload -eq "Nvidia") { 
                Write-Host -NoNewline "  Attempting transcode to 1080p HEVC (this may take some time)..."            
                ./ffmpeg -hide_banner -v $hevc_verbose -y -i $video_path -vf scale=1920:-1 -map 0 -c:v hevc_nvenc -preset hq -profile:v main10 -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                $convert_error = $LASTEXITCODE     

            }

            elseif ($video_codec -ne "hevc" -AND $hevc_offload -eq "Nvidia") { 
                Write-Host -NoNewline "  Attempting transcode to HEVC (this may take some time)..."            
                ./ffmpeg -hide_banner -v $hevc_verbose -y -i $video_path -map 0 -c:v hevc_nvenc -preset hq -profile:v main10 -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                $convert_error = $LASTEXITCODE
                
            }

            #CPU Offload... (evaluated last) 
            elseif ($convert_1080p -eq 1 -AND $video_width -gt 1920) { 
                Write-Host -NoNewline "  Attempting transcode to 1080p HEVC (this may take some time)..."            
                ./ffmpeg -hide_banner -v $hevc_verbose -y -i $video_path -vf scale=1920:-1 -map 0 -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
                $convert_error = $LASTEXITCODE     

            }

            elseif ($video_codec -ne "hevc") { 
                Write-Host -NoNewline "  Attempting transcode to HEVC (this may take some time)..."            
                ./ffmpeg -hide_banner -v $hevc_verbose -y -i $video_path -map 0 -c:a copy -c:s copy -gops_per_idr 1 -max_muxing_queue_size 9999 output\$video_name
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

            echo "$video_name ($count/$batch_size, $run_time_current/$scan_period)" >> transcode.log            

            if ($convert_error -eq 0) {          

                #check size of new file 
                $video_new = gci output\$video_name | select Fullname, extension, length
                $video_new_size = [math]::Round($video_new.length / 1GB, 2)
                $diff = $video_size - $video_new_size
                $diff = [math]::Round($diff, 2)
                $total_saved = $total_saved + $diff
                $diff_percent = [math]::Round((1 - ($video_new_size / $video_size)) * 100, 2)

                echo "  Transcode time: $start_time -> $end_time (duration: $total_time_formated)" >> transcode.log  
                if ($video_width -gt 1920) { echo "  New Transcoded Video Width: $video_width -> 1920" >> transcode.log }
                echo "  Video size (GB): $video_size -> $video_new_size (HEVC SAVED! $diff)" >> transcode.log
                
                Write-Host "COMPLETE"
                Write-Host "  Duration : $total_time_formated, GB Saved : $diff ($video_size -> $video_new_size) or $diff_percent percent"
                       

                #confirm move file is enabled, and confirm file is 50% smaller or non-zero 
                if ($move_file -eq 1 -AND $diff_percent -gt 30 -AND $diff_percent -lt 95 -AND $video_new_size -ne 0) {                  

                    $delay = 10 
                    Write-Host -NoNewline "  Sleep before copy ($delay seconds)..."
                    while ($delay -gt 0) {
                        
                        Write-Host -NoNewline "$delay..."
                        Sleep 1
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
                    Write-Host "  File - NOT copied"
                }         
                
            }

            Else {   
                
                if ($video_codec -eq "hevc") {
                    Write-Host "  HEVC skipped" 
                    echo "  SKIPPED, (Codec: $video_codec, Width : $video_width, Size (GB): $video_size)" >> transcode.log
                }
                else {
                    Write-Host "  ERROR or FAILED (ExitCode: $convert_error)" 
                    echo "  ERROR or FAILED, (ExitCode: $convert_error, Codec: $video_codec, Width : $video_width, Size (GB): $video_size)" >> transcode.log
                }        
                                          
            }  
            
            Write-Host "Batch : $count/$batch_size, Time : $run_time_current/$scan_period, Total GB Saved: $total_saved " 

            # Update skip.txt with failed, hevc or already processed file 
            echo "$video_name" >> skip.log
            $count = $count + 1

            if ($count -ge $batch_size) { break }
            if ($run_time_current -ge $scan_period) { break }
          
        }      
              
    }

}
