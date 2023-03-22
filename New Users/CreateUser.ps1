# Set the log file path and name
$LogFolderPath = "C:\importusers\CreateUser Logs\"
$Date = Get-Date -Format "yyyy-MM-dd"
$Time = Get-Date -Format "hh-mm-ss tt"
$LogFileName = "CreateUser_$($Date)_$($Time).log"
$LogFilePath = Join-Path -Path $LogFolderPath -ChildPath $LogFileName


# Start the transcript and save output to the log file
Start-Transcript -Path $LogFilePath

function CreateNewUserProfile {
         New-ADUser @userProps
         Set-ADUser -Identity $SamAccountName -Add @{'proxyAddresses' = $proxyAddresses | % { "SMTP:$_" }}

         $homeShare = New-Item -path $HomeDirectory -ItemType Directory -force
 
         $UserSID = Get-ADUser -Identity $samAccountName
         $acl = Get-Acl $homeShare
         $FileSystemRights = [System.Security.AccessControl.FileSystemRights]"Modify"
         $AccessControlType = [System.Security.AccessControl.AccessControlType]::Allow
         $InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
         $PropagationFlags = [System.Security.AccessControl.PropagationFlags]"InheritOnly"
 
         $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule ($UserSID.SID, $FileSystemRights, $InheritanceFlags, $PropagationFlags, $AccessControlType)
         $acl.AddAccessRule($AccessRule)
 
         Set-Acl -Path $homeShare -AclObject $acl -ea Stop

         $homeWindows = $HomeDirectory+"\WINDOWS"
         $homeShareWIN = New-Item -path $homeWindows -ItemType Directory -force
         $AUJSSource = ".\AUJSINI\AUJS"+$State + ".ini"
         $AUJSDestination = $homeWindows + "\AUJS.ini"
         copy-item -path $AUJSSource -Destination $AUJSDestination
         $GPSource = ".\GPDEX\Dex.ini"
         $GPDestination = $HomeDirectory + "\DEX.ini"
         copy-item -path $GPSource -Destination $GPDestination
 
         Write-Host ("HomeDirectory created at {0}" -f $HomeDirectory)

         New-MsolUser -LicenseAssignment company:ENTERPRISEPACK -UsageLocation US -DisplayName $DisplayName -FirstName $GivenName -LastName $SurName -Password $password -UserPrincipalName $UserPrincipalName
         Set-MsolUser -UserPrincipalName $UserPrincipalName -StrongAuthenticationRequirements $mfa

        #Active Directory Groups
        $Groups = (Get-ADUser $SourceUser –Properties MemberOf).memberof | Get-ADGroup | Select -Expandproperty Name 
        foreach ($name in $Groups) {
            Write-Host  $name
            $ExistingMembers = Get-ADGroupMember -Identity $name -Recursive | Select -Expandproperty Name

            # User already member of group
            if ($ExistingMembers -contains $DisplayName) {
                Write-Host "$SamAccountName already exists in $name" -ForeGroundColor Yellow
            }
            else {
                # Add user to group
                Add-ADGroupMember $name $SamAccountName
                Write-Host "Added $SamAccountName to $Name" -ForeGroundColor Green
            }    

        } #end else

      
        #Copy Azure Memberships - This is for mailboxes with read/write permissions
        $SourceUserAccount = $SourceEmail
        $TargetUserAccount = $EmailAddress

		#Add a delay to ensure user creation is completed
		Write-Host "***Please wait 30 seconds to ensure the user is completely setup in Office 365***" -ForeGroundColor Green
		Start-Sleep -Seconds 30
		
        #Get the Source and Target users
        $SourceUser = Get-AzureADUser -ObjectId $SourceUserAccount
        $TargetUser = Get-AzureADUser -ObjectId $TargetUserAccount
        Write-Host $TargetUserAccount
        Write-Host $TargetUser

        If($SourceUser -ne $Null -and $TargetUser -ne $Null)
        {
            #Get All memberships of the Source user
            $SourceMemberships = Get-AzureADUserMembership -ObjectId $SourceUser.ObjectId | Where-object { $_.ObjectType -eq "Group" }
 
            #Get-AzureADUserOwnedObject -ObjectId $SourceUser.ObjectId
 
            #Loop through Each Group
            ForEach($Membership in $SourceMemberships)
            {
                #Check if the user is not part of the group
                $GroupMembers = (Get-AzureADGroupMember -ObjectId $Membership.Objectid).UserPrincipalName
                If ($GroupMembers -notcontains $TargetUser)
                {
                    #Add Target user to the Source User's group
                    Add-AzureADGroupMember -ObjectId $Membership.ObjectId -RefObjectId $TargetUser.ObjectId -ErrorAction SilentlyContinue
                    Write-host "Added user to Group:" $Membership.DisplayName
                }
            }
        }
        Else
        {
            Write-host "Source or Target user is invalid!" -f Yellow
        }
} 

function SendEmailNotice {

#Prepare an email to IT Support with the login Credentials
$from = "IT <itsupport@>"
$to = "itsupport@"
$subject = “New User: $DisplayName”
$textEncoding = [System.Text.Encoding]::UTF8
$smtpServer = "0.0.0.0"
$GPUsername = $GivenName.ToUpper()

$body ="
        Dear Manager,
        <p> Here are the credentials for $DisplayName<br>
        <p>Computer Username - $SamAccountName<br>
        Computer Password - $password

        <p>Office 365 Username - '$EmailAddress'<br>
        Office 365 Password - $password

        <p> 360 - '$UserPrincipalName'<br>
        360 Password - $password

        <p>**If the user needs a GP or AUJS, see below then setup the accounts accordingly**<br>

        <p>GP Username - $GPUsername<br>
        GP Password - GP2018

        <p>AUJS Username - $SamAccountName<br>
        AUJS Password - $password

        <p>**Note for IT - provision 360, AUJS, GP as needed with the supplied credentials.<br>

        <p>Please forward this information to the users Manager, <br>
        IT Support Team<br> 
        </P>"

#This is what sends the email
Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpServer -bodyasHTML -priority High -Encoding $textEncoding   


} 

#Enable TLS 12
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
#Import active directory module for running AD cmdlets
Import-Module activedirectory
#Install-Module MSOnline
#Install-Module AzureAD
Connect-MsolService
Connect-AzureAD

$Bulk = New-Object System.Management.Automation.Host.ChoiceDescription "&Bulk","Description."
$Single = New-Object System.Management.Automation.Host.ChoiceDescription "&Single","Description."
$Exit = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit","Description."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($Bulk, $Single, $Exit)
$heading = "Add New Users"
$mess = "Are you importing multiple(BULK) or entering a single user?"
$rslt = $host.ui.PromptForChoice($heading, $mess, $options, 1)

#Sets MultiFactor variable
$mf= New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
$mf.RelyingParty = "*"
$mfa = @($mf)

switch ($rslt) {
0{
#Store the data from bulk_import.csv in the $Users variable
$Users = Import-csv .\bulk_import.csv
#Loop through each row containing user details in the CSV file 
foreach ($User in $Users) {
    # Read user data from each field in each row
    # the username is used more often, so to prevent typing, save that in a variable
   $SamAccountName       = $User.SamAccountName

    # Check to see if the user already exists in AD
    if (Get-ADUser -F {SamAccountName -eq $SamAccountName}) {
         #If user does exist, give a warning
         Write-Warning "A user account with username $SamAccountName already exist in Active Directory."
    }
    else {
        # User does not exist then proceed to create the new user account

        # create a hashtable for splatting the parameters
        $SourceUser = $User.TemplateAccount
        $proxyAddresses = $User.EmailAddress
        $GivenName = $User.GivenName
        $Surname = $User.Surname
        $password = $User.password
        $Name = $GivenName + " " + $Surname
        $DisplayName =  $GivenName + " " + $Surname
        $SrcUPN = Get-ADUser -Identity $SourceUser |Select -Expandproperty UserPrincipalName
        $SourceEmail = Get-ADUser -Identity $SourceUser |Select -Expandproperty UserPrincipalName
        $refcharacter = $SrcUPN.IndexOf("@")
        $UserPrincipalName = $user.UserPrincipalName
        $EmailAddress = $User.EmailAddress
        $Department = $User.Department
        $SrcDN = Get-ADUser -Identity $SourceUser |Select -Expandproperty DistinguishedName
        $refcharacter = $SrcDN.IndexOf(",OU")
        $path = $User.path
        $HomeDirectory = $User.HomeDirectory
        $State = $User.State

        $userProps = @{
            SamAccountName             = $User.SamAccountName                   
            Path                       = $User.path      
            GivenName                  = $User.GivenName 
            Surname                    = $User.Surname
            Initials                   = $User.Initials
            Name                       = $User.Name
            DisplayName                = $User.DisplayName
            UserPrincipalName          = $user.UserPrincipalName 
            Department                 = $User.Department
            HomeDirectory              = $User.HomeDirectory
            HomeDrive                  = "U"
            EmailAddress               = $User.EmailAddress
            AccountPassword            = (ConvertTo-SecureString $User.password -AsPlainText -Force) 
            Enabled                    = $true
            ChangePasswordAtLogon      = $false
        }   #end userprops 
        
        Write-host        "SourceUser = "$SourceUser
        Write-host        "proxyAddressesproxyAddresses = "$proxyAddresses
        Write-host        "GivenName = "$GivenName
        Write-host        "Surname = "$Surname
        Write-host        "Name = "$Name
        Write-host        "DisplayName = "$DisplayName
        Write-host        "SrcUPN = "$SrcUPN
        Write-host        "SourceEmail = "$SourceEmail
        Write-host        "UserPrincipalName = "$UserPrincipalName
        Write-host        "EmailAddress = "$EmailAddress
        Write-host        "Department = "$Department
        Write-host        "SrcDN = "$SrcDN
        Write-host        "path = "$path
        Write-host        "HomeDirectory = "$HomeDirectory
        Write-host        "State = "$State  

        &CreateNewUserProfile 
        &SendEmailNotice
    } #end else
   
}
}1{
#Store the inputted data in the $Users variable
$SamAccountName = Read-Host -Prompt "Enter a new UserName"

    if (Get-ADUser -F {SamAccountName -eq $SamAccountName}) {
        #If user does exist, give a warning
        Write-Warning "A user account with username $SamAccountName already exist in Active Directory."
    }
    else {

        $SourceUser = Read-Host -Prompt "Enter the UserName of the template User Account to duplicate"
        $SourceEmail = Read-Host -Prompt "Enter the email of the template User Account to duplicate"
        $GivenName = Read-Host -Prompt "Enter the First Name of the new user" 
        $Surname = Read-Host -Prompt "Enter the Last Name of the new user"
        $password = Read-Host -Prompt "Enter the PASSWORD of the new user"
        $Name = $GivenName + " " + $Surname
        $DisplayName =  $GivenName + " " + $Surname
        $SrcUPN = Get-ADUser -Identity $SourceUser |Select -Expandproperty UserPrincipalName
        $refcharacter = $SrcUPN.IndexOf("@")
        $UserPrincipalName = $SamAccountName + $SrcUPN.Substring($refcharacter)
        $EmailAddress = $SamAccountName + $SrcUPN.Substring($refcharacter)
        $Department = Get-ADUser -Identity $SourceUser |Select -Expandproperty Department
        $SrcDN = Get-ADUser -Identity $SourceUser |Select -Expandproperty DistinguishedName
        $refcharacter = $SrcDN.IndexOf(",OU")
        $path = $SrcDN.Substring($refcharacter+1)
        $proxyAddresses = $EmailAddress
        $HomeDirectory = "\\domain.local\private\UDRIVE\"+$SamAccountName
        $State = Read-Host -Prompt "If this user will be using Jonel, what STATE will be accessed?"
        
        $userProps = @{
            SamAccountName             = $SamAccountName                   
            Path                       = $path      
            GivenName                  = $GivenName 
            Surname                    = $Surname
            Initials                   = $Initials
            Name                       = $Name
            DisplayName                = $DisplayName
            UserPrincipalName          = $UserPrincipalName 
            Department                 = $Department
            HomeDirectory              = $HomeDirectory
            HomeDrive                  = "U"
            EmailAddress               = $EmailAddress
            AccountPassword            = (ConvertTo-SecureString $password -AsPlainText -Force) 
            Enabled                    = $true
            ChangePasswordAtLogon      = $false
        }   #end userprops 
        
        &CreateNewUserProfile 
        &SendEmailNotice
    } #end else

}2{
Exit
}
}

# Stop the transcript
Stop-Transcript

Pause