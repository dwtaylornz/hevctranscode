# powershell 
# github.com/dwtaylornz/hevctranscode
#
# script will continously loop through videos transcoding to HEVC - $scan_period used to control how often disk is scanned for new media
# populate hevc_transcode_vars.ps1 before running this script. 

# grab variables from var file 
. .\hevc_transcode_variables.ps1

Set-Location $ffmpeg_path

#map media drive 
while (!(test-path -PathType container $video_directory) -AND $smb_enabled -eq "true") {
    Start-Sleep 2
    Write-Host -NoNewline "Mapping Drive (assuming smb)... "     
    net use $smb_driveletter \\$smb_server\$smb_share /user:$smb_user $smb_password | Out-Null   
}

# Setup temp output folder, and clear previous transcodes
if (!(test-path -PathType container output)) { new-item -itemtype directory -force -path output | Out-Null }

# Main 
while ($true) {
    
    Write-Host ""

   # Scan or retrive $videos 
    #. .\hevc_transcode_scan.ps1
    
    # Remove-Job -Name "Scan" -Force | Out-Null

    if (-not(test-path -PathType leaf .\scan_results.csv) -or $scan_at_start -eq 1) { 
        # Write-Host  Write-Host "Forcing scan" 
        Start-Job -Name "Scan" -FilePath .\hevc_transcode_scan.ps1 -ArgumentList $ffmpeg_path | Out-Null
        Receive-Job -name "Scan" -wait
    }

    else {
        Write-Host -NoNewline "Getting previous scan results & running scan in background..." 
        $videos = Import-Csv -Path .\scan_results.csv
        $file_count = $videos.Count
        Write-Host "Done ($file_count)"
        Start-Job -Name "Scan" -FilePath .\hevc_transcode_scan.ps1 -ArgumentList $ffmpeg_path | Out-Null
    }
    

    # Get previously skipped files
    Write-Host -NoNewline "Getting previously skipped or completed files..." 
    if ((test-path -PathType leaf skip.log)) { 
        $skipped_files = Get-Content -Path skip.log 
        $skip_count = $skipped_files.Count
    }
    else { $skip_count = 0 }
    $video_count = ($file_count - $skip_count)
    Write-Host "Done ($skip_count)"
    Write-Host ""
    Write-Host "Total videos to process : $video_count. Time before next scan : $scan_period minutes"
     
    
    $count = 1 
    $run_start = (GET-Date)
      
    # For Each video 
    Foreach ($video in $videos) {

        #check media drive still mappped
        while (!(test-path -PathType container $video_directory) -AND $smb_enabled -eq "true") {
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
        
        
            # run background transcode
            . .\hevc_transcode_background.ps1         
       

            if ($convert_error -eq 0) {          

                #check size of new file 
                $video_new = Get-ChildItem output\$video_name | Select-Object Fullname, extension, length
                $video_new_size = [math]::Round($video_new.length / 1GB, 2)
                $diff = $video_size - $video_new_size
                $diff = [math]::Round($diff, 2)
                $total_saved = $total_saved + $diff
                $diff_percent = [math]::Round((1 - ($video_new_size / $video_size)) * 100, 2)

                Write-Output "  Transcode time: $start_time -> $end_time (duration: $total_time_formated)" >> transcode.log  
                if ($video_width -gt 1920) { Write-Output "  New Transcoded Video Width: $video_width -> 1920" >> transcode.log }
                Write-Output "  Video size (GB): $video_size -> $video_new_size (HEVC SAVED! $diff)" >> transcode.log
                
                Write-Host "COMPLETE"
                Write-Host "  Duration : $total_time_formated, GB Saved : $diff ($video_size -> $video_new_size) or $diff_percent percent"
                       

                #confirm move file is enabled, and confirm file is 5% smaller or non-zero 
                if ($move_file -eq 1 -AND $diff_percent -gt 5 -AND $diff_percent -lt 95 -AND $video_new_size -ne 0 -AND $diff -gt 0) {                  

                    $delay = 10 
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
                    Write-Host "  File - NOT copied"
                    Write-Output "  File - NOT copied" >> transcode.log
                }         
                
            }

            Else {   
                
                if ($video_codec -eq "hevc") {
                    Write-Host "  HEVC skipped" 
                    Write-Output "  SKIPPED, (Codec: $video_codec, Width : $video_width, Size (GB): $video_size)" >> transcode.log
                }
                else {
                    Write-Host "  ERROR or FAILED (ExitCode: $convert_error)" 
                    Write-Output "  ERROR or FAILED, (ExitCode: $convert_error, Codec: $video_codec, Width : $video_width, Size (GB): $video_size)" >> transcode.log
                }        
                                          
            }  
            
            $count = $count + 1
            Write-Host "Batch : $count/$video_count, Time : $run_time_current/$scan_period, Total GB Saved: $total_saved " 
            # Write-Output "Batch : $count/$video_count, Time : $run_time_current/$scan_period, Total GB Saved: $total_saved " >> batch.log

            # Update skip.txt with failed, hevc or already processed file 
            Write-Output "$video_name" >> skip.log
            
            if ($run_time_current -ge $scan_period) { break }
          
        }      
              
    }
    Write-Host ""
    $sleep_time = ($scan_period - $run_time_current) 
    if ($sleep_time -gt 0) {
        Write-Host "All files done, waiting $sleep_time minutes before re-scan"
        $sleep_time_secs = $sleep_time * 60
        Start-Sleep $sleep_time_secs
    }
 
}
