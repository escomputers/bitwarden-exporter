### Intent


### One time tasks
1. Install [Powershell > 5.0](how-to/powershell.md)

2. Install [Bitwarden CLI](https://bitwarden.com/help/cli/#download-and-install). If you need to install it, open [Powershell](how-to/powershell.md) and run:
```powershell
# First
.\utils\choco_install.ps1

# Then
choco install bitwarden-cli
```

3. [Create API credentials](how-to/bw_api_credentials.md) from Bitwarden.com

4. [Create generic credentials](how-to/credentials_manager.md) in Windows Credentials Manager:
    - BW_CLIENTID = your BW API client ID
    - BW_CLIENTSECRET = your BW API client secret
    - BW_MASTER_PASSWORD = your BW Vault master password
    - BW_ENC_PASSWORD = your custom encryption key
    
### Usage
On a Powershell window run:
```powershell
.\export_bw_vault.ps1
```
