
function Write-Log  ([string] $LogString) {
    if ($LogString) {
        $Logfile = ".\hevc_transcode.log"
        $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
        $LogMessage = "$Stamp $LogString"
        Write-Output $LogMessage
        Add-content $LogFile -value $LogMessage -Encoding utf8
    }
}

function Write-Skip ([string] $video_name) {
    if ($video_name) { 
        $Logfile = "skip.txt"
        # start-sleep -Seconds (0..5 | get-random)
        Add-content $LogFile -value $video_name -Encoding utf8
    }
}

function Write-SkipError ([string] $video_name) {
    if ($video_name) { 
        $Logfile = "skiperror.txt"
        Add-content $LogFile -value $video_name -Encoding utf8
    }
}

function Write-SkipHEVC ([string] $video_name) {
    if ($video_name) { 
        $Logfile = "skiphevc.txt"
        Add-content $LogFile -value $video_name -Encoding utf8
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
    # Write-Host -NoNewline " Exec Path: " 
    # Write-Host -NoNewLine -ForegroundColor Green "$RootDir"
       
    Write-Host ""    
    Write-Host ""   
         
    if ((get-job -State Running -ea silentlycontinue) ) {
        Write-Host "Currently Running Jobs - "

        get-job -State Running 
        Write-Host ""
    }
}

function Initialize-Folders() {
    # Setup required folders
    if (!(test-path -PathType container output)) { new-item -itemtype directory -force -path output | Out-Null }
}

function Get-Videos() {
    # get-job -State Completed | Remove-Job
    get-job -Name Scan -ea silentlycontinue | Stop-Job -ea silentlycontinue | Out-Null
    if (-not(test-path -PathType leaf .\scan_results.csv) -or $scan_at_start -eq 1) { 
        # Stop-Job Scan -ea silentlycontinue
        Write-Host  -NoNewline "Running file scan... " 
        Start-Job -Name "Scan" -FilePath .\include\job_media_scan.ps1 -ArgumentList $RootDir | Out-Null
        Receive-Job -name "Scan" -wait -Force
        Start-Sleep 2 
        $videos = @(Import-Csv -Path .\scan_results.csv -Encoding utf8)
        $file_count = $videos.Count
        Write-Host " files: " $file_count
    }
    
    else {
        
        Write-Host -NoNewline "Getting previous scan results & running new scan in background: " 
        $videos = @(Import-Csv -Path .\scan_results.csv -Encoding utf8)
        $file_count = $videos.Count
        Write-Host $file_count
        Write-Host ""
        Start-Job -Name "Scan" -FilePath .\include\job_media_scan.ps1 -ArgumentList $RootDir | Out-Null 
    
    }

    return $file_count, $videos
}

function Invoke-HealthCheck() {
    if ($run_health_check -eq 1) { 
        Write-Host "Running health scan..." 
        Start-Job -Name "HealthCheck" -FilePath .\include\job_health_check.ps1 -ArgumentList $RootDir, $videos | Out-Null
    }

}

function Get-Skip() {

    Write-Host -NoNewLine "Getting previously processed files: " 
    if ((test-path -PathType leaf skip.txt)) { 
        $skipped_files = @(Get-Content -Path skip.txt -Encoding utf8)
        $skip_count = $skipped_files.Count
    }
    else { $skip_count = 0 }
    Write-Host "$skip_count"
    return $skip_count, $skipped_files
}

function Get-SkipError() {

    Write-Host -NoNewLine "Getting previously skipped (error) files: " 
    if ((test-path -PathType leaf skiperror.txt)) { 
        $skippederror_files = @(Get-Content -Path skiperror.txt -Encoding utf8)
        $skiperror_count = $skippederror_files.Count
    }
    else { $skiperror_count = 0 }
    Write-Host "$skiperror_count"
    return $skiperror_count, $skippederror_files
}

function Get-SkipHEVC() {

    Write-Host -NoNewLine "Getting previously skipped (HEVC) files: " 
    if ((test-path -PathType leaf skiphevc.txt)) { 
        $skippedhevc_files = @(Get-Content -Path skiphevc.txt -Encoding utf8)
        $skiphevc_count = $skippedhevc_files.Count
    }
    else { $skiphevc_count = 0 }
    Write-Host "$skiphevc_count"
    return $skiphevc_count, $skippedhevc_files
}

function Get-VideosToProcess($file_count, $skip_count) {

    $video_count = ($file_count - $skip_count)
    Write-Host ""
    Write-Host "Total videos to process: $video_count"
}

function Test-VideoPath($path) {

    $check = test-path "$path"

    while ($check -eq $false) {
        start-sleep 2
        write-host "Cannot get to path?..."
        $check = test-path "$path"
    }

}

Export-ModuleMember -Function *