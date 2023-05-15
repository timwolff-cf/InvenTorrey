try {
    $msg = 'Logging in to Azure...';
    Write-Output $msg;
	Connect-AzAccount -Identity;
} catch {
    Write-Error -Message $_.Exception;
    throw $_.Exception;
}
Select-AzSubscription -SubscriptionId 9a09c126-ca50-4406-a438-899badcf2828

# Define Variables
$NameOfContainer = 'resourceinventory'
$ReportDate = (Get-Date).ToString("yyyyMMdd")

$resources = Get-AzResource
$fileName = "resources$ReportDate.txt"
$storeageAccount = Get-AzStorageAccount -ResourceGroupName rg-resourceinventory-eastus #| Where-Object {$_.StorageAccountName -eq 'resourceinventory'}
$body = Get-AzResource

# Set variables for the Azure Storage account and container
$key = Get-AzStorageAccountKey -ResourceGroupName $storeageAccount.ResourceGroupName -Name $storeageAccount.StorageAccountName
$ctx = New-AzStorageContext -StorageAccountName $storeageAccount.StorageAccountName -StorageAccountKey $key[0].Value
$containerName = Get-AzStorageContainer -Context $ctx -Name $storeageAccount | Where-Object {$_.Name -eq $NameOfContainer}
$containerName = $containerName.Name
$storageAccountName = $storeageAccount.StorageAccountName
$sasToken = New-AzStorageBlobSASToken -Container $containerName -Context $ctx -Blob $fileName -Permission "rwa"

# Set the URI for the Azure Storage Blob service
$uri = "https://$storageAccountName.blob.core.windows.net/$containerName/$fileName$sasToken"

  
 $blobUploadParams = @{  
     URI = "{0}/{1}?{2}" -f $StorageURL, $FileName, $SASToken  
     Method = "PUT"  
     Headers = @{  
         'x-ms-blob-type' = "BlockBlob"  
         'x-ms-blob-content-disposition' = "attachment; filename=`"{0}`"" -f $FileName  
         'x-ms-meta-m1' = 'v1'  
         'x-ms-meta-m2' = 'v2'  
     }  
     Body = $Content  
     Infile = $FileToUpload  
 }  
Invoke-WebRequest -Uri $blobUploadParams.URI -Method $blobUploadParams.Method -Headers $blobUploadParams.Headers -InFile $blobUploadParams.Infile -UseBasicParsing  