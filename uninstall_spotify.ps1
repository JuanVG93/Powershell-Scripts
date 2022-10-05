# This Powershell script will attempt to uninstall Spotify from a system
# Written by: Juan van Genderen
# Date: 04/10/2022

# This function will check the running status of the Spotify Process
Function CheckrunningProcess {
  try {
    # Checking for running processes called Spotify and rerouting the output to null because we don't want to see the result
    $Status = Get-Process -Name "spotify" 2>$null
    if ($Status) {
      Return $True
      else {
        Return $False
      }
    }
  }
  catch {
    Write-Output "Error Message: " $_.Exception.Message
		Write-Output "Error Processing: " $_.Rolename
		Write-Output "Error in Line: " $_.InvocationInfo.Line
		Write-Output "Error in Line Number: "$_.InvocationInfo.ScriptLineNumber
		Write-Output "Error Item Name: "$_.Exception.ItemName
  }
}

# This function will attempt to uninstall spotify for each user on the machine
Function UninstallSpotify {
  param
	(
    [Parameter(Mandatory = $true)] [string]$Path,
    [Parameter(Mandatory = $true)] [string]$WorkingDirectory,
    [Parameter(Mandatory = $true)] [string]$User
	)

  try {
      # Checking if Spotify is installed for the User we're looping through
      Write-Output "Checking if Spotify is installed for $User..."
      # Checking if the path to the Spotify.exe exists
      if (Test-Path -Path $Path) {
        Write-Output "Spotify is installed..."
        Write-Output "Proceeding to uninstall Spotify"
        # Running the Spotify app with command line arguments for silently uninstalling the app
        Start-Process -FilePath $Path\Spotify.exe -ArgumentList "/uninstall /silent"
        Write-Output "Spotify uninstalled... Please wait a moment"
        # We wait for 10 seconds to ensure the uninstall process is finished
        Start-Sleep -s 10
        Write-Output "Cleaning up..."
        # Remove potential files left over by Spotify
        Remove-Item $WorkingDirectory\appdata\roaming\spotify -Force -Recurse 2>$null
        Remove-Item $WorkingDirectory\appdata\local\spotify -Force -Recurse 2>$null
        Remove-Item $WorkingDirectory\desktop\spotify.lnk -Force -Recurse 2>$null
      }
      # Spotify doesn't appear to be installed
      else {
        Write-Output "Spotify is not installed..."
      }
  }
  catch {
    Write-Output "Error Message: " $_.Exception.Message
		Write-Output "Error Processing: " $_.Rolename
		Write-Output "Error in Line: " $_.InvocationInfo.Line
		Write-Output "Error in Line Number: "$_.InvocationInfo.ScriptLineNumber
		Write-Output "Error Item Name: "$_.Exception.ItemName
  }
  # Ensuring any artifacts left by Spotify are removed
  Write-Output "Removing any artifacts left by Spotify"
  # Calling RemoveSpotifyArtifacts function
  RemoveSpotifyArtifacts
}

# This function will remove any artifacts leftover by Spotify
Function RemoveSpotifyArtifacts {
  # Locate the HKEY_USERS registry folder
  $HKEYUSERS = Get-ChildItem -Path Microsoft.Powershell.Core\Registry::HKEY_USERS
  try {
    Write-Output "Checking for leftover registry keys"
    # Looping through all the registry keys to find keys for Spotify
    ForEach ($Key in $HKEYUSERS) {
      if (Test-Path Microsoft.PowerShell.Core\Registry::\$Key\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Spotify) {
        Write-Output "Key Found: $Key"
        # Remove key if found
        Remove-Item Microsoft.PowerShell.Core\Registry::\$Key\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Spotify -Force -Recurse
        Write-Output "Key Removed..."
      }
    }
  }
  catch {
    Write-Output "Error Message: " $_.Exception.Message
		Write-Output "Error Processing: " $_.Rolename
		Write-Output "Error in Line: " $_.InvocationInfo.Line
		Write-Output "Error in Line Number: "$_.InvocationInfo.ScriptLineNumber
		Write-Output "Error Item Name: "$_.Exception.ItemName
  }
}

# Main function
Function Main {
  Write-Output "Checking if the Spotify app is running..."
  # Taking note of the state of the Spotify process
  $Running = CheckrunningProcess
  # Check if the Spotify process is running
  if ($Running) {
    Write-Output "Spotify is running..."
    Write-Output "Killing the Spotify App"
    # Killing the Spotify process
    Stop-Process -Name "spotify" -Force
    Write-Output "Spotify successfully killed"
  }
  else {
    # Spotify doesn't appear to be running
    Write-Output "Spotify is not running..."
  }
  # Gathering all the users present on the machine
  Write-Output "Gathering all the Users present on this machine..."
  # Calling the UninstallSpotify function
  $UserDirectory = Get-ChildItem -Directory "c:\users"
  $WorkingDirectory = "c:\Users\" + "$User"
  try {
  ForEach ($User in $UserDirectory) {
    $Path = "c:\Users\$($User)\AppData\roaming\Spotify\"
    UninstallSpotify -Path $Path -User $User -WorkingDirectory $WorkingDirectory
  }
  Write-Output "Done!"
}
  catch {
    Write-Output "Error Message: " $_.Exception.Message
    Write-Output "Error Processing: " $_.Rolename
    Write-Output "Error in Line: " $_.InvocationInfo.Line
    Write-Output "Error in Line Number: "$_.InvocationInfo.ScriptLineNumber
    Write-Output "Error Item Name: "$_.Exception.ItemName
  }
}

Main
