
$state = Get-Content .\test.txt -Tail 1 | Select-String -Pattern 'time'

$Delimiter=" ";
$Array=$state -Split $Delimiter;
$time_taken = Write-Output $Array[8];
$time_taken = $time_taken.trim()
