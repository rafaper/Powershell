#
# Script.ps1
#
$myRG = $null
$myVm = $null
$myVmObj = $null
$myVnet = $null
$myVnetObj = $null
$mySubBackend = $null
$mySubBackendObj = $null

function ManageNetworkInterfaces {

        echo "Would you like to [A]dd or [D]elete a Network Interface?"
        $answer = Read-Host
        Switch($answer.ToUpper())
        {
            A {
                echo "Please name the new Network Interface:"
                $newNICinput = Read-Host
		        echo "Please enter the location for the new Network Interface (use lower-case and no spaces):"
		        $newNICLocation = Read-Host
		        echo "Please enter the Network Security Group name:"
		        $newNICnsg = Read-Host
                echo "Creating new Network Interface."
		        $newNICnsgId = (Get-AzNetworkSecurityGroup -ResourceGroupName $myRG -Name $newNICnsg).Id
		        $newNIC = New-AzNetworkInterface -Name $newNICinput -ResourceGroupName $myRG -Location $newNICLocation -SubnetId $mySubBackendObj.Id -NetworkSecurityGroupId $newNICnsgId
                $newNicId = (Get-AzNetworkInterface -ResourceGroupName $myRG -Name $newNICinput).Id
		        $script:myVmObj = Add-AzVMNetworkInterface -VM $myVmObj -Id $newNicId -Primary
                echo "Updating Virtual Machine."
		        Update-AzVm -ResourceGroupName $myRG -VM $myVmObj
                Write-Host "Action Complete." -ForegroundColor Green
            }   
            D {
                Get-AzNetworkInterface
                echo "Enter the name of the Network Interface you would like to remove:"
                $removeNICinput = Read-Host
		        $removeNIC = (Get-AzNetworkInterface -ResourceGroupName $myRG -Name $removeNICinput).Id
                echo "Removing Network Interface."
                Remove-AzVMNetworkInterface -VM $myVmObj -NetworkInterfaceIDs $removeNIC
                echo "Updating Virtual Machine."
		        Update-AzVm -ResourceGroupName $myRG -VM $myVmObj
		        Write-Host "Action Complete." -ForegroundColor Green
            }
    }
}

function LoadConfigFile {
    echo "Please enter the full file path without quotes:"
    $configFilePath = Read-Host

    echo "Loading config file inputs..."
    $configContents = Get-Content $configFilePath.Replace('"',"")

    $script:myRG = $configContents[0].split("=")[1].Trim(" ")
    $script:myVm = $configContents[1].split("=")[1].Trim(" ")
    $script:myVnet = $configContents[2].split("=")[1].Trim(" ")
    $mySubBackend = $configContents[3].split("=")[1].Trim(" ")

    $script:myVmObj = Get-AzVM -ResourceGroupName $myRG -Name $myVm
    $script:myVnetObj = Get-AzVirtualNetwork -Name $myVnet -ResourceGroupName $myRG
    $script:mySubBackendObj = $myVnetObj.Subnets|?{$_.Name -eq $mySubBackend}
    echo "Loading complete."
}

function RunWithoutConfigFile {

    echo "Loading Resource Groups..."
    Get-AzResourceGroup
    echo "Enter Resource Group Name to list existing VMs:"
    $script:myRG = Read-Host

    echo "Loading Virtual Machines..."
    Get-AzVM -ResourceGroupName $myRG
    echo "Enter name of VM you would like to edit?"
    echo "Please note adding/removing NICs will require VM to be shut down."
    $script:myVm = Read-Host
    $script:myVmObj = Get-AzVM -ResourceGroupName $myRG -Name $myVm

    Stop-AzVM -ResourceGroupName $myRG -Name $myVm

    echo "Enter the name of the Virtual Network associated with the VM:"
    $script:myVnet = Read-Host
    $script:myVnetObj = Get-AzVirtualNetwork -Name $myVnet -ResourceGroupName $myRG

    echo "Enter the name of the Subnet Backend associated with the VM:" 
    $script:mySubBackend = Read-Host
    $script:mySubBackendObj = $myVnetObj.Subnets|?{$_.Name -eq $mySubBackend}
}

Connect-AzAccount
$sub =  Get-AzSubscription
$subId = (($sub).SubscriptionId | Select -First 1).toString()

echo "Would you like to use the inputs from a config .txt file? [y/n]"
$useConfigFile = Read-Host

if($useConfigFile -eq "n")
{
    RunWithoutConfigFile
    ManageNetworkInterfaces
}
else
{
    LoadConfigFile
    ManageNetworkInterfaces
}

echo "Would you like to start the Virtual Machine? [y/n]"
$startVM = Read-Host

if($startVM -eq "y")
{
    Start-AzVM -ResourceGroupName $myRG -Name $myVm 
}


