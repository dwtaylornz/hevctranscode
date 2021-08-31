# powershell 
# github.com/dwtaylornz/hevctranscode
#
# script will continously loop through videos transcoding to HEVC
# populate variables.ps1 before running this script. 

Clear-Host
$RootDir = Get-Location
Import-Module ".\include\functions.psm1" -Force

# Get-Variables
. .\variables.ps1

# Setup temp output folder, and clear previous transcodes
Initialize-Folders
  
# Get Videos - run Scan job at $media_path or retrive videos from .\scan_results
$file_count, $videos = Get-Videos

# run health check job 
Invoke-HealthCheck

# Get previously skipped files from skip.log
# Show-Skip
Write-Host -NoNewline "Getting previously skipped or completed files: " 
if ((test-path -PathType leaf skip.log)) { 
    $skipped_files = @(Get-Content -Path skip.log)
    $skip_count = $skipped_files.Count
}
else { $skip_count = 0 }
Write-Host "$skip_count"
    
# Show total videos to process (scanned files - skip count) 
# Show-ToProcess
$video_count = ($file_count - $skip_count) 
Write-Host "Total videos to process: $video_count"

#Show settings and any jobs running 
Show-State

#Main Loop across videos 
Foreach ($video in $videos) {

    $video_size = [math]::Round($video.length / 1GB, 2)
    
    if ($video_size -lt $min_video_size) { Wait-Quit }

    if ($($video.name) -notin $skipped_files) {

        while ($true) {

            $done = 0

            for ($thread = 1; $thread -le $GPU_threads; $thread++) {
                # get thread state 
                $gpu_state = Get-JobStatus "GPU-$thread"

                # clear completed or stopped jobs 
                if ($gpu_state -eq "Completed" -OR $gpu_state -eq "Stopped") { 
                    Receive-Job -name "GPU-$thread" 
                    remove-job -name "GPU-$thread" -Force 
                }   

                # If thread not running then i can run it here 
                if ($gpu_state -ne "Running") {
                    if ($ffmpeg_hwdec -eq 1) { $hw = "DE" }
                    else { $hw = "E" }
                    Start-Job -Name "GPU-$thread" -FilePath .\include\job_transcode.ps1 -ArgumentList $RootDir, $video, "GPU($thread$hw)" | Out-Null 
                    $done = 1 
                    break
                }       

                # Output existing jobs 
                if ($gpu_state -eq "Running" ) { 
                    Receive-Job -name "GPU-$thread" 
                }  
            }          
            if ($done -eq 1) { break }
        }
    }
}
Wait-Quit