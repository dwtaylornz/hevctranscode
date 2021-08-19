# powershell 
# github.com/dwtaylornz/hevctranscode
#
# script will continously loop through videos transcoding to HEVC
# populate hevc_transcode_variables.ps1 before running this script. 

$RootDir = Get-Location
Import-Module ".\include\functions.psm1" -Force

# Get-Variables
. .\hevc_transcode_variables.ps1

#map media drive 
if ($smb_enabled) {
    Test-SMB ($media_path) 
}

# Setup temp output folder, and clear previous transcodes
if (!(test-path -PathType container output)) { new-item -itemtype directory -force -path output | Out-Null }
if (!(test-path -PathType container logs)) { new-item -itemtype directory -force -path logs | Out-Null }    

Write-Host " "
   
# run Scan job at $media_path or retrive videos from .\scan_results

if (-not(test-path -PathType leaf .\scan_results.csv) -or $scan_at_start -eq 1) { 
    Write-Host  -NoNewline "Running file scan..." 
    Start-Job -Name "Scan" -FilePath .\include\job_media_scan.ps1 -ArgumentList $RootDir | Out-Null
    Receive-Job -name "Scan" -wait
    $videos = Import-Csv -Path .\scan_results.csv   
    $file_count = $videos.Count
    Write-Host "Done ($file_count)" 
  
}

else {
    Write-Host -NoNewline "Getting previous scan results & running new scan in background..." 
    $videos = Import-Csv -Path .\scan_results.csv   
    $file_count = $videos.Count
    Write-Host "Done ($file_count)" 
        
    if ((get-job -Name Scan -ea silentlycontinue) ) {
        $scan_state = (get-job -Name Scan).State 
        if ($scan_state -ne "Running") { 
            Remove-job Scan
            Start-Job -Name "Scan" -FilePath .\include\job_media_scan.ps1 -ArgumentList $RootDir | Out-Null 
        }
    }

    else {
        Start-Job -Name "Scan" -FilePath .\include\job_media_scan.ps1 -ArgumentList $RootDir | Out-Null 
    }
}
    
if ($run_health_check -eq 1) { 
    Write-Host "Running health scan..." 
    Start-Job -Name "HealthCheck" -FilePath .\include\job_health_check.ps1 -ArgumentList $RootDir, $videos | Out-Null
}

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
Trace-Message "Total videos to process : $video_count"

if ((test-path -PathType leaf skip.log)) { $skipped_files = Get-Content -Path skip.log }
else { $skipped_files = "" }

get-job -State Running
Write-Host " "

Foreach ($video in $videos) {
    
    if ($smb_enabled) {
        Test-SMB ($media_path) 
    }

    $video_size = [math]::Round($video.length / 1GB, 2)
    
    if ($video_size -lt $min_video_size) {
        Trace-Message "ALL DONE - Video smaller than defined $min_video_size, waiting for jobs to finish then quiting"

        while (get-job -State Running -ea silentlycontinue) {
            Start-Sleep 1
            Receive-Job *
        }   
        Trace-Message "exiting"
        Break
    }

    $video_name = $video.name

    if ($video_name -notin $skipped_files) {

        while ($true) {

            $done = 0

            for ($thread = 1; $thread -le $GPU_threads; $thread++) {
                # get thread state 
                $gpu_state = Get-JobStatus "GPU-Transcode-$thread"

                # clear completed or stopped jobs 
                if ($gpu_state -eq "Completed" -OR $gpu_state -eq "Stopped") { 
                    Receive-Job -name "GPU-Transcode-$thread" 
                    remove-job -name "GPU-Transcode-$thread" -Force 
                }   

                # Output existing jobs 
                if ($gpu_state -eq "Running" ) { 
                    Receive-Job -name "GPU-Transcode-$thread" 
                }   

                # If thread not running then i can run it here 
                if ($gpu_state -ne "Running") {
                    Start-Job -Name "GPU-Transcode-$thread" -FilePath .\include\job_transcode.ps1 -ArgumentList $RootDir, $video, "GPU($thread)" | Out-Null 
                    $done = 1 
                    break
                }       
                   
            }          

            if ($done -eq 1) { break }
        }

    }
}