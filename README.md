# Teams Live Event Traffic Distributor

## What it is

This solution was built to load balance users between a number of Microsoft Teams Live Events, since one Event can only host a couple of thousand clients. So instead of distributing the Live Event URLs to the users directly, they are given the URL to this solution. By default, this is the URL of Azure Front Door, e.g. `myliveevent.azurefd.net`, instead of a URL to the Teams Event directly. To achieve the load balancing, APIM Management is being used to randomly redirect client requests, using HTTP 302 status code, to a URL of the actual Live Event.

Note: The URL can be changed by either using a URL shortener like Bitly or also by adding your own custom domain to Front Door (e.g. `myliveevent.contoso.com`).

## Azure Components

The solution deploys three components:

- Azure Front Door for global load balancing and failover
- 2x Azure API Management in Consumption tier, in two different regions for resiliency
- Azure Application Insights including on Azure Portal Dashboard for monitoring

## Alternative use cases

While the solution was originally built for Teams Live Events, it can easily be repurposed for any kind of similar load balancing.

## How to use

(optional) [Build](https://github.com/Azure/bicep) bicep - if you didn't make any changes, you can also just use the main.json ARM template file from the repo which was already generated
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

## Costs 
(only provided as an example, as of Feb-2021)

Overall cost for this solution is pretty minimal. The only reoccurring billing (without any incoming traffic), is for the Front Door routing configuration. All other costs are purely based on incoming traffic / usage.

- API Management - Consumption tier: $3.50 per 1 million calls. And the first 1 million calls per Azure subscription are free. [Pricing](https://azure.microsoft.com/en-us/pricing/details/api-management/)
- Front Door: $0.01 per GB incoming traffic, $0.17 per GB response traffic (Zone 1), $22 per month for the two routing rules. [Pricing](https://azure.microsoft.com/en-us/pricing/details/frontdoor/)
- Application Insights: $2.88 per GB ingested data - and the first 5 GB per billing account are included per month. [Pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/) 