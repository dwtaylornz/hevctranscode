function Trace-Message([string] $message) {
    Write-Output "$(Get-Date -Format G): $message"
    Write-Output "$(Get-Date -Format G): $message" >> hevctranscode.log
}

Export-ModuleMember -Function *
