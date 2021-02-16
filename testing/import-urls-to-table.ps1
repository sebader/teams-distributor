Install-Module AzTable

$urls = Get-Content sample-url-list.txt # url-list.txt needs to contain the list of backend URLs, one per line

Write-Host "Fount $($urls.Count) URLs to import"

$resourceGroup = "teamsdistributor" # <-- Change me!

$tableName = "Urls" # does not need to be changed unless it was changed in the ARM template
$partitionKey = "event1" # does not need to be changed

# Get all storage accounts in the resource group
$storageAccounts = Get-AzStorageAccount -ResourceGroupName $resourceGroup

foreach ($storageAccount in $storageAccounts) {
    Write-Host "Importing data into storage account $($storageAccount.StorageAccountName)"
    $ctx = $storageAccount.Context

    $cloudTable = (Get-AzStorageTable –Name $tableName –Context $ctx).CloudTable

    $i = 0
    foreach ($url in $urls) {
        Add-AzTableRow `
            -Table $cloudTable `
            -PartitionKey $partitionKey `
            -RowKey ($i) `
            -Property @{"url" = "$url" } `
            -UpdateExisting

        $i++
    }
}