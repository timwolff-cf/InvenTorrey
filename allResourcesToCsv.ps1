<#
This runbook gathers all Azure Resources from the Get-AzResource PowerShell command and writes the output to a 
.csv file in a blob storage container.
#>

# Define Variables
$NameOfContainer = 'resourceinventory'
$ReportDate = (Get-Date).ToString("yyyyMMdd")
$fileName = "AllResources$ReportDate.csv"
$automationAccount = "aa-resourceinventory"
$UAMI = "mi-cf-operations"
$method = "UA"
$resourceGroup = "rg-cf-resourceinventory"

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process | Out-Null

# Connect using a Managed Service Identity
try {
        #$AzureContext = (Connect-AzAccount -Identity -Tenant $tenant -SubscriptionId $subscription).context
        $AzureContext = (Connect-AzAccount -Identity).context
    }
catch{
        Write-Output "There is no system-assigned user identity. Aborting."; 
        exit
    }

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription `
    -DefaultProfile $AzureContext

if ($method -eq "SA")
    {
        Write-Output "Using system-assigned managed identity"
    }
elseif ($method -eq "UA")
    {
        Write-Output "Using user-assigned managed identity"

        # Connects using the Managed Service Identity of the named user-assigned managed identity
        $identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroup `
            -Name $UAMI -DefaultProfile $AzureContext

        # validates assignment only, not perms
        if ((Get-AzAutomationAccount -ResourceGroupName $resourceGroup `
                -Name $automationAccount `
                -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId))
            {
                $AzureContext = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

                # set and store context
                $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
            }
        else {
                Write-Output "Invalid or unassigned user-assigned managed identity"
                exit
            }
    }
else {
        Write-Output "Invalid method. Choose UA or SA."
        exit
     }

Select-AzSubscription -SubscriptionId (Get-AzContext).Subscription.id

$resources = Get-AzResource
$storeageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroup #| Where-Object {$_.StorageAccountName -eq 'resourceinventory'}

# Set variables for the Azure Storage account and container
$key = Get-AzStorageAccountKey -ResourceGroupName $storeageAccount.ResourceGroupName -Name $storeageAccount.StorageAccountName
$ctx = New-AzStorageContext -StorageAccountName $storeageAccount.StorageAccountName -StorageAccountKey $key[0].Value
$containerName = Get-AzStorageContainer -Context $ctx -Name $storeageAccount | Where-Object {$_.Name -eq $NameOfContainer}
$containerName = $containerName.Name
$storageAccountName = $storeageAccount.StorageAccountName
$sasToken = New-AzStorageBlobSASToken -Container $containerName -Context $ctx -Blob $fileName -Permission "rwa"

# Set the URI for the Azure Storage Blob service
#$uri = "https://$storageAccountName.blob.core.windows.net/$containerName/$fileName$sasToken"
$resources | Export-Csv $fileName
  
 $blobUploadParams = @{  
     URI = "https://$storageAccountName.blob.core.windows.net/$containerName/$fileName$sasToken"
     Method = "PUT"  
     Headers = @{  
         'x-ms-blob-type' = "BlockBlob"  
         'x-ms-blob-content-disposition' = "attachment; filename=`"{0}`"" -f $FileName  
         'x-ms-meta-m1' = 'v1'  
         'x-ms-meta-m2' = 'v2'  
     }  
     Body = $fileName  
     Infile = $fileName  
 }  
Invoke-WebRequest -Uri $blobUploadParams.URI -Method $blobUploadParams.Method -Headers $blobUploadParams.Headers -InFile $blobUploadParams.Infile -UseBasicParsing  
