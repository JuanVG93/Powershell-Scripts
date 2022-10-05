# This script allows you to verify whether a list of users or single exist(s) in Azure AD
Function Main {
	# The path to the user list text file
	$Path = "C:\Automation\Powershell Scripts\UserList.txt"
	# Testing the path to ensure it exists and is accessible
	$Check = Test-Path -Path $Path
	# If we pass the test, verify that there's content in the file
	if ($Check) {
		$UseFile = (Get-ChildItem -Path $Path).Length -ne "0"
	}
	# If we have content, we read the file and loop through each user in the list
	if ($UseFile) {
			$UserList = Get-Content -path $Path
			Write-Host "[INFO] Looping through all the users listed in $Path" -ForegroundColor Yellow
			# Start of loop
			foreach ($User in $UserList) {
				# Noting whether the account is active (exists)
				$UserState = CheckAADUserActive($User)
				# If the account exists, proceed to verify the account type
				if ($UserState) {
					CheckAADUserAccountType -User $User
				}
			}
	} 
	else {
		# We assume the user wants to check a single account
		Write-Host "[INFO] The UserList.txt file is empty or doesn't exist... Assuming you want to check a single user" -ForegroundColor Yellow
		# Use the input field as the user parameter
		$User = Read-Host "Please enter a username"
		# Noting whether the account is active (exists)
		$UserState = CheckAADUserActive($User)
		# If the account exists, proceed to verify the account type
		if ($UserState) {
			CheckAADUserAccountType -User $User
		}
	}
}

# This function will check whether an AAD User is active
Function CheckAADUserActive {
	param
	(
		[Parameter(Mandatory = $true)] [string]$User
	)
	try {
		$User = $User -replace "'","''"
		$UserPrincipalName = (Get-AzureADUser -Filter "startswith(userPrincipalName, '$User')")
		if (!$UserPrincipalName) {
			Write-Host "ERROR: $User was not found" -Foregroundcolor Red
			Return $False
		} 
		else {
			Return $True
		}
	} 
	catch {
		Write-Host "`nError Message: " $_.Exception.Message
		Write-Host "`nError Processing: " $_.Rolename
		Write-Host "`nError in Line: " $_.InvocationInfo.Line
		Write-Host "`nError in Line Number: "$_.InvocationInfo.ScriptLineNumber
		Write-Host "`nError Item Name: "$_.Exception.ItemName
	}
}

# This function will check what type of AAD User E.G: Guest, Member
Function CheckAADUserAccountType ([Parameter(Mandatory = $true)] [string]$User){
	try {
		$UserType = (Get-AzureADUser -ObjectId $User).UserType
		Write-Host "$User does exist and is a $($UserType) account" -Foregroundcolor Green
	} 
	catch {
		Write-Host "`nError Message: " $_.Exception.Message
		Write-Host "`nError Processing: " $_.Rolename
		Write-Host "`nError in Line: " $_.InvocationInfo.Line
		Write-Host "`nError in Line Number: "$_.InvocationInfo.ScriptLineNumber
		Write-Host "`nError Item Name: "$_.Exception.ItemName
	}
}

# Calling the Main function
Main
