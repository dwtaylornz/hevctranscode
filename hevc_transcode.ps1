# powershell 
# github.com/dwtaylornz/hevctranscode
#
# script will loop through largest to smallest videos transcoding to HEVC
# populate variables.ps1 before running this script. 
# TODO - make it multi machine! 

Set-Location $PSScriptRoot
$RootDir = $PSScriptRoot
if ($RootDir -eq "") {
    $RootDir = $pwd
}

Import-Module ".\include\functions.psm1" -Force

Write-Host ""
Write-Log "Starting..."
Write-Host ""

# Get-Variables
. (Join-Path $RootDir variables.ps1)

# Setup temp output folder, and clear previous transcodes
Initialize-Folders
  
# Get Videos - run Scan job at $media_path or retrive videos from .\scan_results
$file_count, $videos = Get-Videos

# run health check job 
Invoke-HealthCheck

#Show settings and any jobs running 
Show-State

# if single machine here - 
$skipped_files = Get-Skip
$skiptotal_files = $skipped_files + $skippederror_files + $skippedhevc_files

#Main Loop across videos 
Foreach ($video in $videos) {

    # Write-Host -NoNewline "."
    # if multi machine here - 
    # $skipped_files = Get-Skip
    # $skiptotal_files = $skipped_files + $skippederror_files + $skippedhevc_files

    if ($($video.name) -notin $skiptotal_files) {

        $video_size = [math]::Round($video.length / 1GB, 2)
    
        if ($video_size -lt $min_video_size) { 
            Write-Log "HIT VIDEO SIZE LIMIT - waiting for running jobs to finish then quiting"
            while (get-job -State Running -ea silentlycontinue) {
                Start-Sleep 1
                Receive-Job *
            }   
            Write-Log "exiting"
            Read-Host -Prompt "Press any key to continue"
            exit
        }

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

                # has thread run too long? 
                $now = Get-Date
                Get-Job -name GPU-* | Where-Object { $_.State -eq 'Running' -and (($now - $_.PSBeginTime).TotalMinutes -gt $ffmpeg_timeout) } | Stop-Job

                # If thread not running then i can run it here 
                if ($gpu_state -ne "Running") {
                    if ($ffmpeg_hwdec -eq 1) { $hw = "DE" }
                    else { $hw = "E" }
                    Start-Job -Name "GPU-$thread" -FilePath .\include\job_transcode.ps1 -ArgumentList $RootDir, $video, "GPU($thread$hw)" | Out-Null 
                    $done = 1 
                    break
                }       
                
                Receive-Job -name *
            }          
            if ($done -eq 1) { break }
        }
    }
}
Write-Log "ALL DONE - waiting for running jobs to finish then quiting"
while (get-job -State Running -ea silentlycontinue) {
    Start-Sleep 1
    Receive-Job *
}   
Write-Log "exiting"
Start-Sleep 10
#Read-Host -Prompt "Press any key to continue"
exit