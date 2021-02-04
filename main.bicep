param locationPrimary string = 'northeurope'
param locationSecondary string = 'westeurope'
param prefix string
param apimPublisherEmail string = 'noreply@contoso.com'
param apimPublisherName string = 'Contoso Admin'

param backends string

param deploymentId string {
  default: utcNow()
  metadata: {
    description: 'ID to be added to the deployment names, such as the run ID of a pipeline. Default to UTC-now timestamp'
  }
}

var frontDoorName = '${prefix}globalfrontdoor'
var frontdoor_default_dns_name = '${frontDoorName}.azurefd.net'

resource appinsights 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: '${prefix}appinsights'
  location: locationPrimary
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

module apimPrimaryRegion 'module_apim.bicep' = {
  name: 'apim-${locationPrimary}-${deploymentId}'
  params: {
    applicationInsightsName: appinsights.name
    location: locationPrimary
    backends: backends
    prefix: prefix
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
}

module apimSecondaryRegion 'module_apim.bicep' = {
  name: 'apim-${locationSecondary}-${deploymentId}'
  params: {
    applicationInsightsName: appinsights.name
    location: locationSecondary
    backends: backends
    prefix: prefix
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
  }
}

resource frontdoor 'Microsoft.Network/frontDoors@2020-05-01' = {
  name: frontDoorName
  location: 'Global'
  properties: {
    backendPools: [
      {
        name: 'BackendAPIMs'
        properties: {
          backends: [
            {
              address: apimPrimaryRegion.outputs.apimHostname
              backendHostHeader: apimPrimaryRegion.outputs.apimHostname
              httpPort: 80
              httpsPort: 443
              priority: 1
              weight: 50
            }
            {
              address: apimSecondaryRegion.outputs.apimHostname
              backendHostHeader: apimSecondaryRegion.outputs.apimHostname
              httpPort: 80
              httpsPort: 443
              priority: 1
              weight: 50
            }
          ]
          healthProbeSettings: {
            id: '${resourceId('Microsoft.Network/frontDoors', frontDoorName)}/healthProbeSettings/HealthProbeSetting'
          }
          loadBalancingSettings: {
            id: '${resourceId('Microsoft.Network/frontDoors', frontDoorName)}/loadBalancingSettings/LoadBalancingSettings'
          }
        }
      }
    ]
    frontendEndpoints: [
      {
        name: 'DefaultFrontendEndpoint'
        properties: {
          hostName: frontdoor_default_dns_name
          sessionAffinityEnabledState: 'Disabled'
        }
      }
      /*
      // Enable this if you have a custom domain name available
      {
        name: 'CustomDomainFrontendEndpoint'
        properties: {
          hostName: customDomainName_frontdoor
          sessionAffinityEnabledState: 'Disabled'
          webApplicationFirewallPolicyLink: {
            id: wafPolicy.id
          }
        }
      }
      */
    ]
    routingRules: [
      {
        name: 'HTTPSRedirect'
        properties: {
          acceptedProtocols: [
            'Http'
          ]
          patternsToMatch: [
            '/*'
          ]
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorRedirectConfiguration'
            redirectProtocol: 'HttpsOnly'
            redirectType: 'Moved'
          }
          frontendEndpoints: [
            {
              id: '${resourceId('Microsoft.Network/frontDoors', frontDoorName)}/frontendEndpoints/DefaultFrontendEndpoint'
            }
          ]
        }
      }
      {
        name: 'DefaultBackendForwardRule'
        properties: {
          acceptedProtocols: [
            'Https'
          ]
          patternsToMatch: [
            '/*'
          ]
          routeConfiguration: {
            '@odata.type': '#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration'
            backendPool: {
              id: '${resourceId('Microsoft.Network/frontDoors', frontDoorName)}/backendPools/BackendAPIMs'
            }
            forwardingProtocol: 'HttpsOnly'
          }
          frontendEndpoints: [
            {
              id: '${resourceId('Microsoft.Network/frontDoors', frontDoorName)}/frontendEndpoints/DefaultFrontendEndpoint'
            }
          ]
        }
      }
    ]
    healthProbeSettings: [
      {
        name: 'HealthProbeSetting'
        properties: {
          healthProbeMethod: 'HEAD'
          path: '/healthz'
          protocol: 'Https'
          intervalInSeconds: 30
        }
      }
    ]
    loadBalancingSettings: [
      {
        name: 'LoadBalancingSettings'
        properties: {
          additionalLatencyMilliseconds: 200
          sampleSize: 4
          successfulSamplesRequired: 2
        }
      }
    ]
  }
}