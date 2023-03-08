# exportNsgRules.ps1

# The code retrieves Azure subscriptions and stores them in a variable called $subs.
$subs = Get-AzSubscription

# The script loops through each subscription and selects it using Select-AzSubscription cmdlet. 
# It then retrieves all the Network Security Groups (NSGs) within the selected subscription using Get-AzNetworkSecurityGroup cmdlet.
foreach ($sub in $subs) {
    Select-AzSubscription -SubscriptionId $sub.Id
    $nsgs = Get-AzNetworkSecurityGroup

    # For each NSG, the script retrieves all its Security Rules using the SecurityRules property.
    foreach ($nsg in $nsgs) {
        $nsgRules = $nsg.SecurityRules

        # For each Security Rule within an NSG, the script selects specific properties and creates a custom object with these properties.
        # The custom object includes additional properties to identify the subscription, resource group, and NSG name.
        # The custom object is then exported to a CSV file with a timestamp in the filename.
        foreach ($nsgRule in $nsgRules) {
            $nsgRule | Select-Object @{n='SubscriptionName';e={$sub.Name}},
                @{n='ResourceGroupName';e={$nsg.ResourceGroupName}},
                @{n='NetworkSecurityGroupName';e={$nsg.Name}},
                Name,Description,Priority,
                @{Name='SourceAddressPrefix';Expression={[string]::join(",", ($_.SourceAddressPrefix))}},
                @{Name='SourcePortRange';Expression={[string]::join(",", ($_.SourcePortRange))}},
                @{Name='DestinationAddressPrefix';Expression={[string]::join(",", ($_.DestinationAddressPrefix))}},
                @{Name='DestinationPortRange';Expression={[string]::join(",", ($_.DestinationPortRange))}},
                Protocol,Access,Direction |
                    Export-Csv ./NSGs_"$((Get-Date).ToString("yyyyMMdd_HHmmss")).csv" -NoTypeInformation -Encoding ASCII -Append        
        }
    }
}
