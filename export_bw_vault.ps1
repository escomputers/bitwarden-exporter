# Constants
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$TaskName = "BackupBWVaultTask"
$ScriptPath = "$PSCommandPath"

# Define the Desktop path and ExportPath
$DesktopPath = [System.Environment]::GetFolderPath("Desktop")
$ExportFolder = Join-Path -Path $DesktopPath -ChildPath "bitwarden-exports"
$ExportPath = Join-Path -Path $ExportFolder -ChildPath "bitwarden_encrypted_export_$($timestamp).json"

# Ensure the export folder exists
if (-not (Test-Path -Path $ExportFolder)) {
    try {
        New-Item -ItemType Directory -Path $ExportFolder -Force | Out-Null
        Write-Output "Folder '$ExportFolder' created successfully."
    } catch {
        Write-Error "Failed to create folder '$ExportFolder'. Error: $_"
        exit 1
    }
}


# Function to check and install a module if not present
function EnsureModule {
    param (
        [string]$ModuleName  # Name of the module to check/install
    )

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Output "Module '$ModuleName' not found. Installing it now"
        try {
            Install-Module -Name $ModuleName -Force
            Write-Output "Module '$ModuleName' installed successfully"
        } catch {
            Write-Error "Failed to install module '$ModuleName'. Error: $_"
            exit 1
        }
    }

    # Import the module
    try {
        Import-Module -Name $ModuleName -ErrorAction Stop
    } catch {
        Write-Error "Failed to import module '$ModuleName'. Error: $_"
        exit 1
    }
}


# Ensure CredentialManager module is installed and imported
EnsureModule -ModuleName "CredentialManager"

# Check if Bitwarden CLI is installed
if (-not (Get-Command "bw" -ErrorAction SilentlyContinue)) {
    throw "Bitwarden CLI is not installed. Please install it"
}


# Function to create a scheduled task for daily execution at 2pm
function EnsureTaskScheduler {
    param (
        [string]$TaskName,
        [string]$ScriptPath
    )

    # Check if the task already exists
    $taskExists = Get-ScheduledTask | Where-Object { $_.TaskName -eq $TaskName }

    if ($null -eq $taskExists) {
        Write-Output "Creating scheduled task '$TaskName'."

        try {
            # Create a new task trigger for daily execution at 2pm
            $Trigger = New-ScheduledTaskTrigger -Daily -At 2:00PM

            # Create the action to run the script with PowerShell
            $Action = New-ScheduledTaskAction `
                -Execute "pwsh.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

            # Create a Settings object for storing Task specific settings
            $Settings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -StartWhenAvailable `
                -DontStopIfGoingOnBatteries `
                -WakeToRun `
                -MultipleInstances IgnoreNew

            # Register the scheduled task
            Register-ScheduledTask `
                -TaskName $TaskName  `
                -Settings $Settings `
                -Trigger $Trigger `
                -Action $Action `
                -Description "Backup Bitwarden Vault"

            Write-Output "Scheduled task '$TaskName' created successfully"
        } catch {
            Write-Error "Failed to create scheduled task '$TaskName'. Error: $_"
            exit 1
        }
    } else {
        Write-Output "Scheduled task '$TaskName' already exists"
    }
}


# Ensure the task scheduler is set up
EnsureTaskScheduler -TaskName $TaskName -ScriptPath $ScriptPath


# Convert a SecureString to Plain Text
function Convert-SecureStringToPlainText {
    param (
        [System.Security.SecureString]$SecureString
    )

    try {
        # Convert the SecureString to plain text
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        )
    } catch {
        # Handle any exceptions during the conversion
        Write-Error "An error occurred while converting the SecureString to plain text: $_"
        exit 1
    }
}


# Set the converted plain text secret as an environment variable
function Set-CredentialAsEnvVariable {
    param (
        [PSCredential]$Credential,  # Credential object containing the target name
        [string]$EnvVariableName    # Name of the environment variable to set
    )

    # Convert the secure string password to plain text
    $PlainTextPassword = Convert-SecureStringToPlainText -SecureString $Credential.Password

    # Set the plain text password as an environment variable
    [Environment]::SetEnvironmentVariable($EnvVariableName, $PlainTextPassword, "Process")
}


# Function to retrieve and validate a credential from Credential Manager
function Get-AndValidateCredential {
    param (
        [string]$ExpectedSecretName  # The expected name of the credential
    )

    # Retrieve the credential from Credential Manager
    $Credential = Get-StoredCredential -Target $ExpectedSecretName

    # Validate the credential
    if ($null -eq $Credential) {
        Write-Error "Generic secret '$ExpectedSecretName' is null or was not found in the Credential Manager"
        exit 1
    }

    # Return the credential if validation passes
    return $Credential
}


# Login to BW server, Authenticate to BW vault and finally export the
# encrypted JSON file
function BackupBWVault {
    # Ensure session logout before starting it up
    bw logout
    
    # Get the current vault server
    Write-Output "`n"
    $ServerOutput = bw config server
    bw config server $ServerOutput
    
    # Login
    Write-Output "`n"
    bw login --apikey
    
    # Get the session token, needed for vault unlock
    $SessionToken = bw unlock --passwordenv BW_MASTER_PASSWORD --raw
    
    # Export vault with the --password parameter specified
    # This allows to import the file into a different Bitwarden account
    # File will be encrypted using that password instead of master password
    Write-Output "`n"
    bw export `
        --format encrypted_json `
        --session $SessionToken `
        --password "$Env:BW_ENC_PASSWORD" `
        --output $ExportPath
    
    # Logout
    Write-Output "`n"
    bw logout
    Write-Output "`n"
}


# Retrieve credential from Credentials Manager, then convert it to plain text
# and finally set it as environment variable for the process
Set-CredentialAsEnvVariable -Credential (Get-AndValidateCredential -ExpectedSecretName "BW_CLIENTID") -EnvVariableName "BW_CLIENTID"
Set-CredentialAsEnvVariable -Credential (Get-AndValidateCredential -ExpectedSecretName "BW_CLIENTSECRET") -EnvVariableName "BW_CLIENTSECRET"
Set-CredentialAsEnvVariable -Credential (Get-AndValidateCredential -ExpectedSecretName "BW_ENC_PASSWORD") -EnvVariableName "BW_ENC_PASSWORD"
Set-CredentialAsEnvVariable -Credential (Get-AndValidateCredential -ExpectedSecretName "BW_MASTER_PASSWORD") -EnvVariableName "BW_MASTER_PASSWORD"
Write-Output "Environment variables set successfully"

# Start backup of Bitwarden vault by exporting the encrypted JSON file
BackupBWVault
