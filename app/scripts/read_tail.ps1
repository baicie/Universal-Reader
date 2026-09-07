$path = 'D:\workspace\git-code\Universal-Reader\app\test\library_controller_test.dart'
$bytes = [System.IO.File]::ReadAllBytes($path)
Write-Output ('Total bytes: ' + $bytes.Length)
$tail = $bytes[-30..-1]
$hex = ($tail | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
Write-Output $hex
Write-Output '---'
Write-Output ([System.Text.Encoding]::UTF8.GetString($tail))
