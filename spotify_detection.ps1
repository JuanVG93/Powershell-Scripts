# This function will detect whether Spotify is installed by verifying if it's associated registry keys can be found for any user on a machine
Function SpotifyState {
  # Locate the HKEY_USERS registry folder
  $HKEYUSERS = Get-ChildItem -Path Microsoft.Powershell.Core\Registry::HKEY_USERS
  try {
    # Looping through all the registry keys to find keys for Spotify
    ForEach ($Key in $HKEYUSERS) {
      while (Test-Path Microsoft.PowerShell.Core\Registry::\$Key\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Spotify) {
        Write-Output "Spotify is installed"
        Exit 0;
      }
    }
    Write-Output "Spotify is not installed"
    Exit 1;
  }
  catch {
    Write-Output "Error Message: " $_.Exception.Message
    Write-Output "Error Processing: " $_.Rolename
    Write-Output "Error in Line: " $_.InvocationInfo.Line
    Write-Output "Error in Line Number: "$_.InvocationInfo.ScriptLineNumber
    Write-Output "Error Item Name: "$_.Exception.ItemName
  }
}

SpotifyState
