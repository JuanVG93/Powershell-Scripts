# This script will allow you to update the membership of multiple users that exist in Azure AD by reading the requirements from a .csv file
Function Main {
	# The path to the user list CSV file
	$Path = "C:\Automation\Powershell Scripts\Users.csv"
	# Testing the path to ensure it exists and is accessible
	$Check = Test-Path -Path $Path
	# If we pass the test, verify that there's content in the file
	if ($Check) {
		$UseFile = (Get-ChildItem -Path $Path).Length -ne "0"
	}
	# If we have content, we read the file and loop through each user in the list
	if ($UseFile) {
			$UserList = Import-Csv -path $Path
			Write-Host "[INFO] Looping through all the users listed in $Path" -ForegroundColor Yellow
			# Asking whether we want to Add or Remove the user
			$AddRemoveCheck = (Read-Host -prompt "The options are: Add | Remove | Check")
			
			Switch ($AddRemoveCheck) 
			{
				Add {
					# Start of loop
					foreach($User in $UserList) {
						# Calling UserMembership function to confirm the user membership status and passing the Add switch
						UserMembership -User $User.UPN -Group $User.AADGROUP -Add
					}
				}
				Remove {
					# Start of loop
					foreach($User in $UserList) {
						# Calling UserMembership function to confirm the user membership status and passing the Remove switch
						UserMembership -User $User.UPN -Group $User.AADGROUP -Remove
					}
				}
				Check {
					foreach($User in $UserList) {
						# Calling UserMembership function to confirm the user membership status and passing the Check switch
						UserMembership -User $User.UPN -Group $User.AADGROUP -Check
					}
				}
			}
	}
	
	else {
		# We assume the user wants to check a single account
		Write-Host "[INFO] The Users.csv file is empty or doesn't exist... Assuming you want to check a single user" -ForegroundColor Yellow
		# Use the input field as the user parameter
		[String]$User = Read-Host "Please enter a username"
		# Use the input field as the group parameter
		[String]$Group = Read-Host "Please enter a AAD group"
		# Do we want to Add or Remove the users from the supplied AAD group?
		$AddRemoveCheck = (Read-Host -prompt "The options are: Add | Remove | Check")
		Switch ($AddRemoveCheck) {
			Add {
				# Calling UserMembership function to confirm the user membership status and passing the Add switch
				UserMembership -User $User -Group $Group -Add
			}
			Remove {
				# Calling UserMembership function to confirm the user membership status and passing the Remove switch
				UserMembership -User $User -Group $Group -Remove
			}
			Check {
				# Calling UserMembership function to confirm the user membership status and passing the Check switch
				UserMembership -User $User -Group $Group -Check
			}
		}
	}
}

# This function will check if the users are a member of the AAD groups found in the Halo Role Mapping document
Function UserMembership {
	param
	(
		[Parameter(Mandatory = $true)] [string]$User,
		[Parameter(Mandatory = $true)] [string]$Group,
		[Parameter(Mandatory = $false)] [Switch]$Remove,
		[Parameter(Mandatory = $false)] [Switch]$Add,
		[Parameter(Mandatory = $false)] [Switch]$Check
	)
	# Check if the user is a member of the AAD Group supplied
	$Member = (Get-AzureADUserMembership -ObjectId $User | Where-Object {$_.DisplayName -eq $Group})
	try {
		# Check if we want to remove the user
		if ($Remove.IsPresent) {
			if ($Member) {
				# Call the ModifyUserGroup function and supply the Remove switch
				ModifyUserGroup -User $User -Group $Group -Remove
			}
			else {
				Write-Host "$User is not a member of $Group" -ForegroundColor Yellow
			}
		}
		# Check if we want to add the user
		if ($Add.IsPresent) {
			if (!$Member) {
				# Call the ModifyUserGroup function and supply the Add switch
				ModifyUserGroup -User $User -Group $Group -Add
			}
			else {
				Write-Host "$User is already a member of $Group" -ForegroundColor Yellow
			}
		}
		# When we only want to verify the membership
		if ($Check.IsPresent) {
			if ($Member) {
				Write-Host "$User is a member of $Group" -ForegroundColor Green
				}
				else {
					Write-Host "$User is not a member of $Group" -ForegroundColor Red
				}
		}
	}			
	catch {
		Write-Host "`nError Message: " $_.Exception.Message -ForegroundColor Red
		Write-Host "`nError Processing: " $_.Rolename -ForegroundColor Red
		Write-Host "`nError in Line: " $_.InvocationInfo.Line -ForegroundColor Red
		Write-Host "`nError in Line Number: "$_.InvocationInfo.ScriptLineNumber -ForegroundColor Red
		Write-Host "`nError Item Name: "$_.Exception.ItemName -ForegroundColor Red
	}
}

# This function will allow you to add or remove an AAD group from a user
Function ModifyUserGroup {
    param 
    (   
        [Parameter(Mandatory = $true)] [string]$User,
        [Parameter(Mandatory = $true)] [string]$Group,     
        [Parameter(Mandatory = $false)] [Switch]$Remove,
		[Parameter(Mandatory = $false)] [Switch]$Add
    )
    try {	
		# Capturing the User ObjectID
        $UserObjectID = $(Get-AzureADUser -ObjectId $User).ObjectId
		# Capturing the Group ObjectID
        $GroupObjectID = $(Get-AzureADGroup -All $True | Where-Object {$_.DisplayName -eq $Group}).ObjectId
		
		# Check is we want to remove the user
        if($Remove.IsPresent) {
			# Check if the user is a member
			if($Member) {
				# Only remove the user if they are currently a member
				Remove-AzureADGroupMember -ObjectId $GroupObjectID -MemberId $UserObjectID
				Write-Host "$User was removed from AAD Group $Group" -ForegroundColor Green
			}
			# When the user isn't a member at the time of checking we do nothing
			else {
				Write-Host "$User is not a member of $Group" -ForegroundColor Yellow
			}
		}
		# Check if we want to add the user
        if ($Add.IsPresent) {
			# Check if the user isn't a member
			if(!$Member) {
				# Only add the user if they aren't currently a member
				Add-AzureADGroupMember -ObjectId $GroupObjectID -RefObjectId $UserObjectID
				Write-Host "$User was added to AAD Group $Group" -ForegroundColor Green
			}
			# When the user is already a member at  the time of checking we do nothing
			else {
				Write-Host "$User is already a member of $Group" -ForegroundColor Yellow
			}
		}
	}
    catch
    {
        Write-Host "`nError Message: " $_.Exception.Message -ForegroundColor Red
        Write-Host "`nError in Line: " $_.InvocationInfo.Line -ForegroundColor Red
        Write-Host "`nError in Line Number: "$_.InvocationInfo.ScriptLineNumber -ForegroundColor Red
        Write-Host "`nError Item Name: "$_.Exception.ItemName -ForegroundColor Red
    }    
}

# Calling the Main function
Main
