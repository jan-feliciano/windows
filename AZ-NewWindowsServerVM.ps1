#Install the Az module if you haven't done so already.
#Install-Module Az
 
#Login to your Azure account.
#Login-AzAccount
 
#Define the following parameters for the virtual machine.
$vmAdminUsername = "rootuser"
$vmAdminPassword = ConvertTo-SecureString "JowyUN0m32020!" -AsPlainText -Force
 
#Define the following parameters for the Azure resources.
$azureVmName                = Read-Host -Prompt "Enter VM Name"
$availableResGroups			= Get-AzResourceGroup  #-Location $azureLocation
$availableResGroups | select ResourceGroupName,Location | format-table | out-string | write-host 
$azureResourceGroup         = Read-Host -Prompt "Enter Resource Group name:"
$azureLocation              = Read-Host -Prompt "Enter Location:"
$azureVmOsDiskName          = $azureVmName+"-OSDisk"
$azureVmSize                = "Standard_D2s_V3"
#"Standard_B1s"
 
#Define the networking information.
$azureNicName               = $azureVmName+"-NIC"
$azurePublicIpName          = $azureVmName+"-IP"
$azureNSG					= $azureVmName+"-NSG"
 
#Define the existing VNet information.
$availablevnet 				= Get-AzVirtualNetwork 
$availablevnet | select Name, Subnets | format-table | out-string | write-host
$azureVnetName              = Read-Host -Prompt "Enter VNet name:"
$azureVnetSubnetName        = "default"
 
#Define the VM marketplace image details.
$azureVmPublisherName = "MicrosoftWindowsServer"
$azureVmOffer = "WindowsServer"
$azureVmSkus = "2019-Datacenter"
 
#Get the subnet details for the specified virtual network + subnet combination.
$azureVnetSubnet = (Get-AzVirtualNetwork -Name $azureVnetName -ResourceGroupName $azureResourceGroup).Subnets | Where-Object {$_.Name -eq $azureVnetSubnetName}
 
#Create the public IP address.
$azurePublicIp = New-AzPublicIpAddress -Name $azurePublicIpName -ResourceGroupName $azureResourceGroup -Location $azureLocation -AllocationMethod Dynamic
 
#Create the NSG and rules.
$RuleConfig = New-AzNetworkSecurityRuleConfig -Name RuleRDP -Protocol Tcp -Direction Inbound -Priority 300 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
$NSG = New-AzNetworkSecurityGroup -ResourceGroupName $azureResourceGroup -Location $azureLocation -Name $azureNSG -SecurityRules $RuleConfig

#Create the NIC and associate the public IP address and NSG.
$azureNIC = New-AzNetworkInterface -Name $azureNicName -ResourceGroupName $azureResourceGroup -Location $azureLocation -SubnetId $azureVnetSubnet.Id -PublicIpAddressId $azurePublicIp.Id -NetworkSecurityGroupId $NSG.Id

#Associate NIC to existing NSG
#Ref: https://docs.microsoft.com/en-us/powershell/module/azurerm.network/set-azurermnetworkinterface?view=azurermps-6.13.0
#NOTE: To use existing NSG"
#--- $nic=Get-AzNetworkInterface -ResourceGroupName $azureResourceGroup -Name $azureNicName
#--- $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $azureResourceGroup -Name $azureNSG
#--- $nic.NetworkSecurityGroup=$nsg
#--- $nic | Set-AzNetworkInterface
 
 
#Store the credentials for the local admin account.
$vmCredential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $vmAdminPassword)
 
#Define the parameters for the new virtual machine.
$VirtualMachine = New-AzVMConfig -VMName $azureVmName -VMSize $azureVmSize
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $azureVmName -Credential $vmCredential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $azureNIC.Id

$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $azureVmPublisherName -Offer $azureVmOffer -Skus $azureVmSkus -Version "latest"
$VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -StorageAccountType "Premium_LRS" -Caching ReadWrite -Name $azureVmOsDiskName -CreateOption FromImage
 
#Create the virtual machine.
New-AzVM -ResourceGroupName $azureResourceGroup -Location $azureLocation -VM $VirtualMachine -Verbose


