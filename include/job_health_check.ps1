Set-Location $args[0]
$videos = $args[1]

Import-Module ".\include\functions.psm1" -Force

Foreach ($video in $videos) {
    $video_duration = 0
    $video_name = $video.name
    $video_path = $video.Fullname
    # Write-Output $video_name
    $video_duration = Get-VideoDuration $video_path
    if ($video_duration -eq 0 -OR $video_duration -lt 1) {
        write-output "I think $video_path is broken, video length = $video_duration"
        write-output $video | Export-Csv unhealthy.csv -append
    }
}