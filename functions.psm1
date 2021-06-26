function Trace-Message([string] $message) {
    Write-Output "$(Get-Date -Format G): $message"
    Write-Output "$(Get-Date -Format G): $message" >> hevctranscode.log
}

function Get-Variables(){
    . .\hevc_transcode_variables.ps1
}

Export-ModuleMember -Function *
