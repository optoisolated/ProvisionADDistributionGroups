#-------------------------------------------------------------------------------------------
# Populate AD Groups Scripts
# 
# This script will create an AD Distribution Group, and add the specified users to it. 
# If the user is an external email address, it will create a contact for them and add it 
# to the group
#
# This script was designed to simplify transporting user groups from Google GSuite to 
# Office365 and somewhat automate the deployment process.
#
# By Default, this script will fail safe, in that it won't create objects if theres a 
# failure of some kind. 


#---- VARIABLES ----------------------------------------------------------------------------
#Specifies the Name of the AD Distribution Group to be created and used
$GroupNamePrefix = "nameofgroup"

#OU of Contacts
$DNPath = "OU=Contacts,OU=Managed Users,DC=domain,DC=organisation,DC=com,DC=au"

#OU of Distro Groups
$DGPath = "OU=DistributionGroups,OU=Managed Users,DC=domain,DC=organisation,DC=com,DC=au"

#CSV of Email Addresses to be added to Distro Group (Emails field)
$EmailAddressList = "C:\Scripts\$($GroupNamePrefix).txt"

#Suffix of Local domain (assumed not to be contacts to be created)
$DomainSuffix = "domain.organisation.com.au"

$EmailAddresses = Import-CSV $EmailAddressList
$GroupName = "$GroupNamePrefix DL"

#---- SOURCE -------------------------------------------------------------------------------

CLS
Import-Module ActiveDirectory

#Create AD Group
Try {
	New-ADGroup -Name $GroupName -SamAccountName $GroupName -GroupCategory Distribution -GroupScope Global -DisplayName $GroupName -Path $DGPath -Description $GroupName
	"$Groupname created successfully."
	}
Catch  {
	"Error Creating Group (Probably exists)"
	}

ForEach ($Address in $EmailAddresses) {
	[string]$EmailAddress = $Address.Email
	"Creating $EmailAddress"
	
	$ContactName = $EmailAddress#.Split("@")[0]
	$DisplayName = $EmailAddress#.Split(".")[0]
	$GroupMember = $EmailAddress.Split("@")[0]
	
	If ($EmailAddress.Split("@")[1] -ne $DomainSuffix ) {
	Try {
		New-ADObject -Type Contact -path $DNPath -Name $ContactName -otherAttributes @{'displayName'=$DisplayName;'mail'=$Emailaddress;}
		# A short delay to allow for domain propagation
		Start-Sleep -s 1
	}
	Catch {
		"Contact exists... skipping."
	}
	} Else {
		"User is of the internal domain, skipping"
	}
	#Add User to Group
	Try {
		If ($EmailAddress.Split("@")[1] -ne $DomainSuffix ) {
			"Attempting to add CN=$($ContactName),$DNPath to group."
			Set-ADGroup -Identity $GroupName -Add @{member="CN=$($ContactName),$DNPath"}
		} Else {
			Add-ADGroupMember -Identity $GroupName -Members $GroupMember -ErrorAction Stop
		}
		"Added to group"
	} 
	Catch {
		$ErrorMessage = $_.Exception.Message
		$FailedItem   = $_.Exception.ItemName
		"Error adding $GroupMember to group. $ErrorMessage ($FailedItem)"
	}
	""
	# A short delay to prevent flooding
	Start-Sleep -s 1
}
