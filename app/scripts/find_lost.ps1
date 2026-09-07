$path = 'C:\Users\20555\.cursor\projects\d-workspace-git-code-Universal-Reader\agent-transcripts\80129725-43b0-4bc3-b415-ff11c0fcb564\80129725-43b0-4bc3-b415-ff11c0fcb564.jsonl'
Select-String -Path $path -Pattern 'annotation store throws|stale pending|waitForSearch|search refresh|note-only' |
  Select-Object -First 20 |
  ForEach-Object {
    Write-Output '---'
    Write-Output ($_.Line.Substring(0, [Math]::Min(220, $_.Line.Length)))
  }
