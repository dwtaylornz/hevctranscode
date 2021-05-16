# powershell 
# github.com/dwtaylornz/hevctranscode
#
# script will continously loop through videos transcoding to HEVC
# populate hevc_transcode_vars.ps1 before running this script. 

#Clear-Host
#$ffmpeg_path = "C:\temp\ffmpeg\bin" # where ffmpeg lives

Set-Location $ffmpeg_path

. .\hevc_transcode_variables.ps1

#map media drive 
while (!(test-path -PathType container $media_path) -AND $smb_enabled -eq "true") {
    Start-Sleep 2
    Write-Host -NoNewline "Mapping Drive (smb enabled)... "     
    net use $smb_driveletter \\$smb_server\$smb_share /user:$smb_user $smb_password | Out-Null   
}

# Setup temp output folder, and clear previous transcodes
if (!(test-path -PathType container output)) { new-item -itemtype directory -force -path output | Out-Null }

Write-Host -NoNewline "Removing any existing running jobs..." 
Get-job | Remove-Job -Force -ea silentlycontinue
# Remove-Item processing.log -Force | Out-Null
Write-Host "Done"

# Main Loop 
while ($true) {
    
    Write-Host " "
   
    $start_time = (GET-Date)

    # run Scan job at $media_path or retrive videos from .\scan_results

    if (-not(test-path -PathType leaf .\scan_results.csv) -or $scan_at_start -eq 1) { 
        Write-Host  "Creating scan results ..." 
        Start-Job -Name "Scan" -FilePath .\job_media_scan.ps1 -ArgumentList $ffmpeg_path | Out-Null
        Receive-Job -name "Scan" -wait
    }

    else {
        Write-Host -NoNewline "Getting previous scan results & running new scan in background..." 
        Start-Job -Name "Scan" -FilePath .\job_media_scan.ps1 -ArgumentList $ffmpeg_path | Out-Null
    }
    
    $videos = Import-Csv -Path .\scan_results.csv
    $cpu_videos = $videos.Clone()
    [array]::Reverse($cpu_videos)
    
    $file_count = $videos.Count
    Write-Host "Done ($file_count)" 

    # Get previously skipped files from skip.log 

    Write-Host -NoNewline "Getting previously skipped or completed files..." 
    if ((test-path -PathType leaf skip.log)) { 
        $skipped_files = Get-Content -Path skip.log 
        $skip_count = $skipped_files.Count
    }
    else { $skip_count = 0 }
    
    # Show total videos to process (scanned files - skip count) 
    $video_count = ($file_count - $skip_count)
    Write-Host "Done ($skip_count)"
    Write-Host ""
    Write-Host "Total videos to process : $video_count. Time before next scan : $scan_period minutes"

    while ($true) {

        # Job Checker 
        # Write-Host  "- second loop" 
        Start-Sleep 1

        # GPU Transcode 
        if ( [bool](get-job -Name GPU-Transcode -ea silentlycontinue) ) {
            $gpu_state = (get-job -Name GPU-Transcode).State 
            #Write-Host "  GPU Job exists and" $gpu_state
            Receive-Job -name "GPU-Transcode"
            if ($gpu_state -eq "Completed") { remove-job -name GPU-Transcode }   
        }
        else {
            #Write-Host "  GPU Job doesnt exist" 
            Start-Job -Name "GPU-Transcode" -FilePath .\job_transcode.ps1 -ArgumentList $ffmpeg_path, $videos, "Largest File" | Out-Null
             
        }

        if ($parallel_cpu_transcode -eq 1) {
            #CPU Transcode 
            if ( [bool](get-job -Name CPU-Transcode -ea silentlycontinue) ) {
                $cpu_state = (get-job -Name CPU-Transcode).State 
                # Write-Host "  CPU Job exists and" $cpu_state
                Receive-Job -name "CPU-Transcode" 
                if ($cpu_state -eq "Completed") { remove-job -name CPU-Transcode }    
            }
            else {
                Write-Host "  CPU Job doesnt exist" 
                Start-Job -Name "CPU-Transcode" -FilePath .\job_transcode.ps1 -ArgumentList $ffmpeg_path, $cpu_videos, "Smallest File" | Out-Null
            }
        }

        $current_time = (GET-Date)
        $timer = New-TimeSpan -Start $start_time -End $current_time
        $time_total_min = $timer.minutes + ($timer.hours * 60)

        #Write-Host "Start Time : $start_time Current Time : $current_time Time so far in min : $time_total_min"

        if ($time_total_min -ge $scan_period) {
            Write-Host ""
            Write-Host -Nonewline "Scan period Expired - "
            Remove-Job Scan -ea silentlycontinue
            Start-Job -Name "Scan" -FilePath .\job_media_scan.ps1 -ArgumentList $ffmpeg_path | Out-Null
            Receive-Job -name "Scan" -wait
            Write-Host "Done" 
            Write-Host ""
            $videos = Import-Csv -Path .\scan_results.csv
            $cpu_videos = $videos.Clone()
            [array]::Reverse($cpu_videos)
            $start_time = (GET-Date)

        }
    }
}