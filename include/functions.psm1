function Trace-Message ([string] $message) {
    Write-Output "$(Get-Date -Format G): $message"
    $mtx = New-Object System.Threading.Mutex($false, "TranscodeMutex")
    If ($mtx.WaitOne(1000)) {
        Write-Output "$(Get-Date -Format G): $message" >> .\logs\hevc_transcode.log
        [void]$mtx.ReleaseMutex()
    }
}

function Trace-Savings ([string] $message) {
    $mtx2 = New-Object System.Threading.Mutex($false, "SavingsMutex")
    If ($mtx2.WaitOne(1000)) {
        Write-Output "$(Get-Date -Format G): $message" >> .\logs\hevc_savings.log
        [void]$mtx2.ReleaseMutex()
    }
}

function Trace-Error ([string] $message) {
    $mtx3 = New-Object System.Threading.Mutex($false, "ErrorMutex")
    If ($mtx3.WaitOne(1000)) {
        Write-Output "$(Get-Date -Format G): $message" >> .\logs\hevc_error.log
        [void]$mtx3.ReleaseMutex()
    }
}

function Write-Skip ([string] $video_name) {
    $mtx4 = New-Object System.Threading.Mutex($false, "SkipMutex")
    If ($mtx4.WaitOne(1000)) {
        Write-Output "$video_name" >> .\skip.log
        [void]$mtx4.ReleaseMutex()
    }
}

function Get-VideoCodec ([string] $video_path) {
    #Write-Host "Check if file is HEVC first..."
    $video_codec = (.\ffprobe.exe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "`"$video_path"`") | Out-String
    if (Select-String -pattern "hevc" -InputObject $video_codec -quiet) { $video_codec = "hevc" }
    if (Select-String -pattern "h264" -InputObject $video_codec -quiet) { $video_codec = "h264" } 
    if (Select-String -pattern "vc1" -InputObject $video_codec -quiet) { $video_codec = "vc1" }          
    if (Select-String -pattern "mpeg2video" -InputObject $video_codec -quiet) { $video_codec = "mpeg2video" }
    if (Select-String -pattern "mpeg4" -InputObject $video_codec -quiet) { $video_codec = "mpeg4" }
    if (Select-String -pattern "rawvideo" -InputObject $video_codec -quiet) { $video_codec = "rawvideo" }
    if (Select-String -pattern "vp9" -InputObject $video_codec -quiet) { $video_codec = "vp9" }
    return $video_codec
}

function Get-VideoWidth ([string] $video_path) {
    #check video width (1920 width is more consistant for 1080p videos)
    $video_width = $null 
    $video_width = (.\ffprobe.exe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
    $video_width = $video_width.trim()
    $video_width = $video_width -as [Int]
    return $video_width
}

function Get-VideoDuration ([string] $video_path) {
    #check video length
    $video_duration = $null 
    $video_duration = (.\ffprobe.exe -v error -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
    $video_duration = $video_duration.trim()
    $video_duration_formated = [timespan]::fromseconds($video_duration)
    $video_duration_formated = ("{0:hh\:mm\:ss}" -f $video_duration_formated)    
    return $video_duration
}

function Get-VideoDurationFormatted ([string] $video_duration) {

    $video_duration_formated = [timespan]::fromseconds($video_duration)
    $video_duration_formated = ("{0:hh\:mm\:ss}" -f $video_duration_formated)    
    return $video_duration_formated
}

function Get-JobStatus ([string] $job) {
    # Write-Host "Checking for any existing running jobs..." 
    if ( [bool](get-job -Name $job -ea silentlycontinue) ) {
        $state = (get-job -Name $job).State 
        # if ($state -eq "Running") { Write-Host "$job Job - Please wait, job already exists and Running"  -ForegroundColor Yellow }
        return $state
    }
}

function Start-Delay {

    Write-Host -NoNewline "  Waiting 5 seconds before file move "
    Write-Host "(do not break or close window)" -ForegroundColor Yellow     
    Start-Sleep 5

}

function Show-State () {

    . .\variables.ps1   
    Write-Host ""
    Write-Host -NoNewLine "Settings - " 
    Write-Host -NoNewline "GPU Type: "
    Write-Host -NoNewLine -ForegroundColor Green "$ffmpeg_codec"
    if ($ffmpeg_hwdec -eq 1) {
        Write-Host -NoNewline " GPU Decoding: "
        Write-Host -noNewLine -ForegroundColor Green "Enabled"
    }
       
    Write-Host ""    
    Write-Host ""   
         
    if ((get-job -State Running -ea silentlycontinue) ) {
        Write-Host "Currently Running Jobs - "

        get-job -State Running 
        Write-Host ""
    }
}

function Wait-Quit () {
    Trace-Message "ALL DONE - waiting for running jobs to finish then quiting"
    while (get-job -State Running -ea silentlycontinue) {
        Start-Sleep 1
        Receive-Job *
    }   
    Trace-Message "exiting"
}

function Initialize-Folders() {

    # Setup temp output folder, and clear previous transcodes
    if (!(test-path -PathType container output)) { new-item -itemtype directory -force -path output | Out-Null }
    if (!(test-path -PathType container logs)) { new-item -itemtype directory -force -path logs | Out-Null }    

}

function Invoke-Scan() {
    . .\variables.ps1  
    if (-not(test-path -PathType leaf .\scan_results.csv) -or $scan_at_start -eq 1) { 
        Write-Host  -NoNewline "Running file scan..." 
        Start-Job -Name "Scan" -FilePath .\include\job_media_scan.ps1 -ArgumentList $RootDir | Out-Null
        Receive-Job -name "Scan" -wait -Force
        Start-Sleep 2 
        $videos = @(Import-Csv -Path .\scan_results.csv -Encoding utf8)
        $file_count = $videos.Count
        Write-Host "Done ($file_count)" 
    }
    
    else {
        Write-Host -NoNewline "Getting previous scan results & running new scan in background..." 
        $videos = @(Import-Csv -Path .\scan_results.csv -Encoding utf8)
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
}

function Invoke-HealthCheck() {
    if ($run_health_check -eq 1) { 
        Write-Host "Running health scan..." 
        Start-Job -Name "HealthCheck" -FilePath .\include\job_health_check.ps1 -ArgumentList $RootDir, $videos | Out-Null
    }

}

function Show-Skip() {

    Write-Host -NoNewline "Getting previously skipped or completed files..." 
    if ((test-path -PathType leaf skip.log)) { 
        $skipped_files = @(Get-Content -Path skip.log)
        $skip_count = $skipped_files.Count
    }
    else { $skip_count = 0 }
}

function Show-ToProcess() {

    $video_count = ($file_count - $skip_count)
    Write-Host "Done ($skip_count)"
    Write-Host ""
    Trace-Message "Total videos to process : $video_count"

    if ((test-path -PathType leaf skip.log)) { $skipped_files = Get-Content -Path skip.log }
    else { $skipped_files = "" }
}

Export-ModuleMember -Function *