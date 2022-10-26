


function Get-VideoCodec ([string] $video_path) {
    #Write-Host "Check if file is HEVC first..."
    $video_codec = (.\ffprobe.exe -v quiet -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "`"$video_path"`")
    # if (Select-String -pattern "hevc" -InputObject $video_codec -quiet) { $video_codec = "hevc" }
    # if (Select-String -pattern "h264" -InputObject $video_codec -quiet) { $video_codec = "h264" } 
    # if (Select-String -pattern "vc1" -InputObject $video_codec -quiet) { $video_codec = "vc1" }          
    # if (Select-String -pattern "mpeg2video" -InputObject $video_codec -quiet) { $video_codec = "mpeg2video" }
    # if (Select-String -pattern "mpeg4" -InputObject $video_codec -quiet) { $video_codec = "mpeg4" }
    # if (Select-String -pattern "rawvideo" -InputObject $video_codec -quiet) { $video_codec = "rawvideo" }
    # if (Select-String -pattern "vp9" -InputObject $video_codec -quiet) { $video_codec = "vp9" }
    return $video_codec
}

function Get-AudioCodec ([string] $video_path) {
    $audio_codec = .\ffprobe.exe -v quiet -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "`"$video_path"`"
    return $audio_codec
}

function Get-VideoWidth ([string] $video_path) {
    #check video width (1920 width is more consistant for 1080p videos)
    $video_width = $null 
    $video_width = (.\ffprobe.exe -v quiet -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
    $video_width = $video_width.trim()
    $video_width = [Int]$video_width
    return $video_width
}

function Get-VideoDuration ([string] $video_path) {
    #check video length
    $video_duration = $null 
    $video_duration = (.\ffprobe.exe -v quiet -select_streams v:0 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1  "`"$video_path"`") | Out-String
    $video_duration = $video_duration.trim()
    $video_duration = [int]$video_duration
    return $video_duration
}

# not getting remainding seconds (as sometimes movie is shortened by a couple)
function Get-VideoDurationFormatted ([string] $video_duration) {
    $video_duration_formated = [timespan]::fromseconds($video_duration)
    $video_duration_formated = ("{0:hh\:mm}" -f $video_duration_formated)    
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

function Show-State() {


    # Get previously skipped files from skip.log
    $skipped_files = Get-Skip
    $skippederror_files = Get-SkipError
    $skippedhevc_files = Get-SkipHEVC

    # $skiptotal_files = $skipped_files + $skippederror_files + $skippedhevc_files
    $skiptotal_count = $skipped_files.Count + $skippederror_files.Count + $skippedhevc_files.Count

    Write-Host "Previously processed files: $($skipped_files.Count)" 
    Write-Host "Previously errored files: $($skippederror_files.Count)" 
    Write-Host "Existing HEVC files: $($skippedhevc_files.Count)" 
    Write-Host ""    
    Write-Host "Total files to skip: $skiptotal_count"


    Write-Host ""

    Write-Host -NoNewLine "Settings - " 
    Write-Host -NoNewline "Encoding: "
    Write-Host -NoNewLine -ForegroundColor Green "$ffmpeg_codec"

    if ($ffmpeg_hwdec -eq 0) {
        Write-Host -NoNewline " Decoding: "
        Write-Host -noNewLine -ForegroundColor Green "CPU"
    }
    if ($ffmpeg_hwdec -eq 1) {
        Write-Host -NoNewline " GPU Decoding: "
        Write-Host -noNewLine -ForegroundColor Green "GPU"
    }
       
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
    
    if (-not(test-path -PathType leaf $media_path\scan_results.csv) -or $scan_at_start -eq 1) { 
        # Stop-Job Scan -ea silentlycontinue
        Write-Host  -NoNewline "Running file scan... " 
        Start-Job -Name "Scan" -FilePath .\include\job_media_scan.ps1 -ArgumentList $RootDir | Out-Null
        Receive-Job -name "Scan" -wait -Force
        Start-Sleep 2 
        $videos = @(Import-Csv -Path $media_path\scan_results.csv -Encoding utf8)
        $file_count = $videos.Count
        Write-Host " files: " $file_count
    }
    
    elseif ($scan_at_start -eq 0) {
        
        Write-Host -NoNewline "Getting previous scan results & running new scan in background: " 
        $videos = @(Import-Csv -Path $media_path\scan_results.csv -Encoding utf8)
        $file_count = $videos.Count
        Write-Host $file_count
        Write-Host ""
        Start-Job -Name "Scan" -FilePath .\include\job_media_scan.ps1 -ArgumentList $RootDir | Out-Null 

    }

    elseif ($scan_at_start -eq 2) {
    
        Write-Host -NoNewline "Getting previous scan results: " 
        $videos = @(Import-Csv -Path $media_path\scan_results.csv -Encoding utf8)
        $file_count = $videos.Count
        Write-Host $file_count
        Write-Host ""
    
    }
    

    return $file_count, $videos
}

function Invoke-HealthCheck() {
    if ($run_health_check -eq 1) { 
        Write-Host "Running health scan..." 
        Start-Job -Name "HealthCheck" -FilePath .\include\job_health_check.ps1 -ArgumentList $RootDir, $videos | Out-Null
    }

}

# File stuff 

function Get-Skip() {
    $cnt = 0
    if ((test-path -PathType leaf $media_path\skip.txt)) { 
        do {
            $cnt++
            try {

                $skipped_files = @(Get-Content -Path $media_path\skip.txt -Encoding utf8 -ErrorAction Stop) 
                return $skipped_files
            }
            catch {
                $rnd = Get-Random -Minimum 1 -Maximum 5
                Start-Sleep $rnd
            }
        } while ($cnt -lt 100)
      
        Write-Host "Unable to read from skip file"  
        exit
        
    }

    return $skipped_files
    
}

function Get-SkipError() {
    $cnt = 0

    if ((test-path -PathType leaf $media_path\skiperror.txt)) { 


        do {
            $cnt++
            try {

                $skippederror_files = @(Get-Content -Path $media_path\skiperror.txt -Encoding utf8 -ErrorAction Stop) 
                return $skippederror_files
            }
            catch {
                $rnd = Get-Random -Minimum 1 -Maximum 5
                Start-Sleep $rnd
            }
        } while ($cnt -lt 100)

        Write-Host "Unable to read from skiperror file"  
        exit

        
    }

    return $skippederror_files
}

function Get-SkipHEVC() {
    $cnt = 0
 
    if ((test-path -PathType leaf $media_path\skiphevc.txt)) { 

        do {
            $cnt++
            try {
                $skippedhevc_files = @(Get-Content -Path $media_path\skiphevc.txt -Encoding utf8 -ErrorAction Stop) 
                return $skippedhevc_files
            }
            catch {
                $rnd = Get-Random -Minimum 1 -Maximum 5
                Start-Sleep $rnd
            }
        } while ($cnt -lt 100)
      
        Write-Host "Unable to read from skiphevc file"  
        exit
    }

    return  $skippedhevc_files
}

function Write-Log  ([string] $LogString) {
    if ($LogString) {
        $Logfile = "$media_path\hevc_transcode.log"
        $Stamp = (Get-Date).toString("yy/MM/dd HH:mm:ss")
        $LogMessage = "$Stamp $env:computername $LogString"
        if ($LogString -like '*transcoding*') { Write-Host "$LogMessage" -ForegroundColor Cyan }
        elseif ($LogString -like '*ERROR*') { Write-Host "$LogMessage" -ForegroundColor Red }
        elseif ($LogString -like '*Saved*') { Write-Host "$LogMessage" -ForegroundColor Green }
        else { Write-Host "$LogMessage" }
        $cnt = 0
    
        do {
            $cnt++
            try {
                Add-content $LogFile -value $LogMessage -Encoding utf8 -ErrorAction Stop
                return 
            }
            catch {
                $rnd = Get-Random -Minimum 1 -Maximum 5
                Start-Sleep $rnd
            }
        } while ($cnt -lt 100)
        Write-Host "Unable to write to log file"  
        exit
    }
}

function Write-Skip ([string] $video_name) {
    if ($video_name) { 
        $Logfile = "$media_path\skip.txt"
        $cnt = 0
    
        do {
            $cnt++
            try {
                Add-content $LogFile -value $video_name -Encoding utf8 -ErrorAction Stop
                return 
            }
            catch {
                $rnd = Get-Random -Minimum 1 -Maximum 5
                Start-Sleep $rnd
            }
        } while ($cnt -lt 100)

        Write-Host "Unable to write to skip file"  
        exit
  
    }
}

function Write-SkipError ([string] $video_name) {
    if ($video_name) { 
        $Logfile = "$media_path\skiperror.txt"
        $cnt = 0
    
        do {
            $cnt++
            try {
                Add-content $LogFile -value $video_name -Encoding utf8 -ErrorAction Stop
                return 
            }
            catch {
                $rnd = Get-Random -Minimum 1 -Maximum 5
                Start-Sleep $rnd
            }
        } while ($cnt -lt 100)
        Write-Host "Unable to write to skiperror file"  
        exit

    }
}

function Write-SkipHEVC ([string] $video_name) {
    if ($video_name) { 
        $Logfile = "$media_path\skiphevc.txt"
        $cnt = 0
    
        do {
            $cnt++
            try {
                Add-content $LogFile -value $video_name -Encoding utf8
                return 
            }
            catch {
                $rnd = Get-Random -Minimum 1 -Maximum 5
                Start-Sleep $rnd
            }
        } while ($cnt -lt 100)

        Write-Host "Unable to write to skiphevc file"  
        exit
    }
}

Export-ModuleMember -Function *
