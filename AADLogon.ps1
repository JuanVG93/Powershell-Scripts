# Logging into AAD
Function LogonAAD {
	#Checking if there's a session active in AzureAD, if no active session then it will log you in
	Write-Host "Checking if you're currently signed into AzureAD" -Foregroundcolor Yellow
	if($azureConnection.Account -eq $null) 
	{
		Write-Host "You're currently not signed into AzureAD" -Foregroundcolor Red
		$AdminUser = whoami /upn
		$AzureConnection = Connect-AzureAD -AccountId $AdminUser
		$ObjectId = (Get-AzureADUser -ObjectId $AdminUser).ObjectId
		Write-Host "You are now signed into AzureAD! Welcome back $AdminUser" -Foregroundcolor Green
		}
		else
		{
			Write-Host "You're already signed into AzureAD!" -Foregroundcolor Green
	}
}
