# Teams Live Event Traffic Distributor

## How to run

(optional) Build bicep - if you didn't make any changes, you can also just use the main.json ARM template file from the repo which was already generated
```
bicep build main.bicep
```

Create resource group
```
az group create -n myresource-group -l northeurope
```

Deploy generated ARM template
```
az deployment group create -g  myresource-group --template-file .\main.json -p prefix=myprefix -p backends="https://stream1.teams.com,https://stream2.teams.com,https://stream3.teams.com"
```