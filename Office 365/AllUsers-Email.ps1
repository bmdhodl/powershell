[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Connect-ExchangeOnline

$emails = Get-EXOMailbox -ResultSize Unlimited | Select-Object  UserPrincipalName,DisplayName,Id,RecipientTypeDetails | Where { $_.RecipientTypeDetails -eq "UserMailbox" }
$NotUserMailbox = Get-DistributionGroupMember -Identity "allusers" -ResultSize Unlimited | Where { $_.RecipientType -ne "UserMailbox" -or $_.RecipientTypeDetails -eq "SharedMailbox" }
    
    foreach ($nonUser in $NotUserMailbox) 
            {
                # Remove user from group
                Remove-DistributionGroupMember -Identity "allusers" -Member "$nonUser" -Confirm:$false 
                Write-Host "$nonUser is either a shared, non-monitored, or inactive mailbox and has been removed" -ForeGroundColor Red 
            }

    foreach ($user in $emails) {
    $SamAccountName = $User.UserPrincipalName
    $DNAME = $User.DisplayName
    $UID = $User.Id
    $ExistingMembers = Get-DistributionGroupMember -Identity "allusers" -ResultSize Unlimited | Where { $_.DisplayName -imatch $DNAME }

            Write-Host "$ExistingMembers   $DNAME    $SamAccountName"
            
            # User already member of group
            if ("$UID" -in "$ExistingMembers") {
                Write-Host "$DNAME already exists in AllUsers Group" -ForeGroundColor Yellow 
            }
            
            else {
                # Add user to group
                Add-DistributionGroupMember -Identity "allusers" -Member "$SamAccountName" -ErrorAction SilentlyContinue
                Write-Host "Added $DNAME to AllUsers Group" -ForeGroundColor Green 
            }
}

# Excluded users here
Remove-DistributionGroupMember -Identity "allusers" -Member "Automate" -Confirm:$false

#Remove-DistributionGroupMember -Identity "allusers" -Member "automate@" -Confirm:$false
Write-Host "Process Has Completed Successfully" -ForegroundColor Green

Get-DistributionGroupMember -Resultsize Unlimited "allusers" | Select DisplayName,PrimarySMTPAddress, WhenMailboxCreated | Export-csv -path "C:\Users\user\Desktop\All User Email List\AllUserEmailList.csv" -NoTypeInformation
Write-Host "Export Complete" -ForeGroundColor Green

#Prepare an email to IT Support with the login Credentials
$from = "IT <itsupport@>"
$to = "@.com"
$subject = “Email List Update Complete”
$textEncoding = [System.Text.Encoding]::UTF8
$smtpServer = "0.0.0.0"
$attachment = "C:\Users\user\Desktop\All User Email List\AllUserEmailList.csv"

$body ="
        **This is an automated message**
        
        Hello,
		
		Here's the weekly All Users Email Export.
		
		Email me if you have any concerns, phughes@.com
		
		Thank you,
        Patrick
        "

#This is what sends the email
Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtpServer -bodyasHTML -priority High -Encoding $textEncoding -Attachments $attachment


Pause