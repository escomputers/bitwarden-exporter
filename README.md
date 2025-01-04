### Purpose
Recently, I learned that many accounts from popular password managers are being unexpectedly and inexplicably deleted.\
This, of course, has a devastating and serious impact and should be avoided at all costs.

So the purpose of this repository is to provide the simplest and fastest solution for automatically backing up your Bitwarden vault on Windows devices.  
This is especially aimed at those who are not "tech-savvy," meaning non-technical users outside the IT world.

### Description
Once you run below steps, you'll have a scheduled task on your Windows PC, running daily at 2pm, exporting the entire vault to a Desktop folder named "bitwarden-exports".
Vault backups are JSON files encrypted with a custom password, so they can be imported into a new/different account.

### One time tasks
1. Install [Powershell > 5.0](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)

2. Install [Bitwarden CLI](https://bitwarden.com/help/cli/#download-and-install). If you need to install it, open Powershell and run:
```powershell
# First
.\utils\choco_install.ps1

# Then
choco install bitwarden-cli
```

3. [Get Bitwarden API credentials](https://bitwarden.com/help/personal-api-key/#get-your-personal-api-key)

4. [Create generic credentials](https://help.sap.com/docs/SAP_BUSINESS_ONE/68a2e87fb29941b5bf959a184d9c6727/ee306036875c4e4391cdd4ca30561c66.html) in Windows Credentials Manager:
    - BW_CLIENTID = your BW API client ID
    - BW_CLIENTSECRET = your BW API client secret
    - BW_MASTER_PASSWORD = your BW Vault master password
    - BW_ENC_PASSWORD = your custom encryption passowrd (this will be required once you import the backup file onto the new account)

### Usage
On a Powershell window run:
```powershell
# Change directory to the one containing the script
# example: cd C:\Users\User\Desktop\bitwarden-exporter

# And then
.\export_bw_vault.ps1
```
