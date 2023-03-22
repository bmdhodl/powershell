Connect-ExchangeOnline
Get-DistributionGroupMember -Resultsize Unlimited "allusers" | Select DisplayName,PrimarySMTPAddress, WhenMailboxCreated | Export-csv -path "C:\Users\administrator.SRMLLC\Desktop\All User Email List\AllUserEmailList.csv" -NoTypeInformation
Write-Host "Export Complete" -ForeGroundColor Green
Pause