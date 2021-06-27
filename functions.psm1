function Trace-Message([string] $message) {
    Write-Output "$(Get-Date -Format G): $message"
    Write-Output "$(Get-Date -Format G): $message" >> hevc_transcode.log
}

Export-ModuleMember -Function *
