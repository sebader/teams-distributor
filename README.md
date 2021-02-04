# Teams Live Event Traffic Distributor

## How to run

Build bicep
```
bicep build main.bicep
```

Create resource group
```
az group create -n myresource-group -l northeurope
```

Deploy generated ARM template
```
az group deployment create -g  myresource-group --template-file .\main.json -p prefix=myprefix -p backends="https://stream1.teams.com,https://stream2.teams.com,https://stream3.teams.com"
```