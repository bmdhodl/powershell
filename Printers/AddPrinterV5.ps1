param (
    [string]$portName = $( Read-Host "Input Port Name, please (I recommend using the IP)" ),
    [string]$portIP = $( Read-Host "Input Printer IP, please" ),
    [string]$printerName = $( Read-Host "Input Printer Name - Match the BPI Name under General in AUJS" ),
    [string]$printDriverName = $( Read-Host "Input Driver Name IF NOT a M4001. IF IT IS a 4001, just Hit ENTER. If you have to type in a driver, here's an example: (Example: HP Laserjet Pro MFP M426)" )
 )
    
    #Default Driver
    if ( $printDriverName -eq "" ) 
        { $printDriverName = "HP LaserJet Pro 4001 4002 4003 4004 PCL-6 (V4)" }

    #Checking the name of the computer from where the script is ran
    $ComputerName = $env:COMPUTERNAME 

    #Gets a list of all drivers on the computer that ran the script
    try {
        $DriverIsReal = Get-PrinterDriver -ComputerName $ComputerName -Name $printDriverName -ErrorAction Stop | Select name -ExpandProperty name 
        if ( $printDriverName -ne $printDriverName )
        { $printDriverName = $printDriverName }
    }
    catch {
        $ErrorMessage = $_
        Write-Host "$printDriverName is an Invalid Driver. $ErrorMessage." -ForeGroundColor Red 
            Pause
            Exit
    }
    
$servers = ("server", "server", "server")
$i=0

function PrintMgmt {   
    #Check for previous printer 
        $printerExists = Get-Printer -ComputerName $printServer -Name $printerName -ErrorAction SilentlyContinue
        $portExists = Get-Printerport -ComputerName $printServer -Name $portname -ErrorAction SilentlyContinue
        $printDriverExists = Get-PrinterDriver -name $printDriverName -ErrorAction SilentlyContinue


    

    Write-Host "Now configuring printer for $printServer." -ForeGroundColor White
        #Check if the printer name exists
        if ($printerExists) {
            Write-Warning "Deleting old $printerName printer."
            Remove-Printer -ComputerName $printServer -Name $printerName
        }

        #Check if the port exists
	    if ($portExists) {
            Write-Warning "Deleting old $portExists port."
            Remove-PrinterPort -ComputerName $printServer -Name $portName
            Write-Host "Adding new $portIP port." -ForeGroundColor Yellow
            Add-PrinterPort -ComputerName $printServer -name $portName -PrinterHostAddress $portIP
        }else{
            Write-Host "Adding new $portIP port." -ForeGroundColor Yellow
            Add-PrinterPort -ComputerName $printServer -name $portName -PrinterHostAddress $portIP
        }

	    
        #Check the driver exists
	    if ($printDriverExists) {
          Write-Host "Adding new $printerName printer." -ForeGroundColor Yellow
      	  Add-Printer -ComputerName $printServer -Name $printerName -PortName $portName -DriverName $printDriverName
	    }else{
      	  Write-Warning "Printer Driver $printDriverName is not installed on your local computer. Install driver and run again."
          #Terminate the script because proceeding is pointless."
          Exit
	    }
    
    Write-Host "Printer $printerName added successfully to $printServer with port IP of $portIP" -ForeGroundColor Green
}

foreach ($printServer in $servers) {
    #Progress Bar
    Write-Progress -Activity "Now configuring $printerName for $printServer with $portIP IP" -Status "$i% Complete:" -PercentComplete $i
            Start-Sleep -Milliseconds 250

    #Call Funtion to Add/Remove Printers
    PrintMgmt

    #Increment Progress Bar
    $i += 10
}

$COM = New-Object System.Management.Automation.Host.ChoiceDescription 'COM-&0-AL,TN'
$COM = New-Object System.Management.Automation.Host.ChoiceDescription 'COM-&1-FL,GA,SC,NC'
$COM = New-Object System.Management.Automation.Host.ChoiceDescription 'COM-&2-CO'
$COM = New-Object System.Management.Automation.Host.ChoiceDescription 'COM-&3-AR,TX'
$COM = New-Object System.Management.Automation.Host.ChoiceDescription 'COM-&4-KY,MI'
$COM = New-Object System.Management.Automation.Host.ChoiceDescription 'COM-&5-NY,NJ,PA'

$options = [System.Management.Automation.Host.ChoiceDescription[]]($COM, $COM, $COM, $COM, $COM, $COM)

$title = 'Add Printer to Com Server'
$message = 'Which Com Server does the printer go on?'
$result = $host.ui.PromptForChoice($title, $message, $options, 0)

switch ($result)
{
    0 { $printServer = "server" 
        #Call Funtion to Add/Remove Printers
        PrintMgmt
      }

    1 { $printServer = "server"
        #Call Funtion to Add/Remove Printers
        PrintMgmt
       }

    2 { $printServer = "server" 
        #Call Funtion to Add/Remove Printers
        PrintMgmt
       }

    3 { $printServer = "server" 
        #Call Funtion to Add/Remove Printers
        PrintMgmt
       }

    4 { $printServer = "server" 
        #Call Funtion to Add/Remove Printers
        PrintMgmt
       }
	   
	5 { $printServer = "server" 
        #Call Funtion to Add/Remove Printers
        PrintMgmt
       }
}

#Final Progress Bar to indicate Printer Addition Success!
Write-Progress -Activity "All Printers Successfully Added!" -Status "$i% Complete:" -PercentComplete $i
            Start-Sleep -Milliseconds 250

Pause