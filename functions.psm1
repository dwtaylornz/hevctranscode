function Trace-Message([string] $message) {
    Write-Output "$(Get-Date -Format G): $message"
}
