# Teams Live Event Traffic Distributor

## What it is

This solution was built to load balance users between a number of Microsoft Teams Live Events, since one Event can only host a couple of thousand clients. So instead of distributing the Live Event URLs to the users directly, they are given the URL to this solution. By default, this is the URL of Azure Front Door, e.g. `myliveevent.azurefd.net`, instead of a URL to the Teams Event directly. To achieve the load balancing, APIM Management is being used to randomly redirect client requests, using HTTP 302 status code, to a URL of the actual Live Event.

Note: The URL can be changed by either using a URL shorter like bitly or also by adding your own custom domain to Front Door (e.g. `myliveevent.contoso.com`).

## Alternative uses

While the solution was originally built for Teams Live Events, it can easily be repurposed for any kind of similar load balancing.

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

Alternatively you can deploy through the Azure Portal directly:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fsebader%2Fteams-distributor%2Fmain%2Fmain.json)
