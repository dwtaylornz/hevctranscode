function Trace-Message ([string] $message) {
    Write-Output "$(Get-Date -Format G): $message"
    Write-Output "$(Get-Date -Format G): $message" >> hevc_transcode.log
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

Export-ModuleMember -Function *