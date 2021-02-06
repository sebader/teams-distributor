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

resource dashboard 'Microsoft.Portal/dashboards@2015-08-01-preview' = {
  name: guid(resourceGroup().name, 'dashboard')
  location: locationPrimary
  tags: {
    'hidden-title': 'Teams Distributor Statistics'
  }
  properties: {
    lenses: {
      '0': {
        order: 0
        parts: {
          '0': {
            position: {
              colSpan: 10
              rowSpan: 5
              x: 0
              y: 0
            }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                {
                  name: 'Scope'
                  value: {
                    resourceIds: [
                      appinsights.id
                    ]
                  }
                }
                {
                  name: 'Dimensions'
                  value: {
                    xAxis: {
                      name: 'timestamp'
                      type: 'datetime'
                    }
                    yAxis: [
                      {
                        name: 'Number of Requests'
                        type: 'long'
                      }
                    ]
                    splitBy: [
                      {
                        name: 'Backend'
                        type: 'string'
                      }
                    ]
                    aggregation: 'Sum'
                  }
                }
                {
                  name: 'PartId'
                  value: guid(resourceGroup().name, 'part0')
                }
                {
                  name: 'Version'
                  value: '2.0'
                }
                {
                  name: 'TimeRange'
                  value: 'PT30M'
                }
                {
                  name: 'Query'
                  value: 'set query_bin_auto_size=5m;\r\nrequests\r\n| extend Backend=tostring(customDimensions[\'Response-location\'])\r\n| where Backend != ""\r\n| summarize [\'Number of Requests\']=count() by Backend, bin_auto(timestamp)\r\n| render areachart'
                }
                {
                  name: 'PartTitle'
                  value: 'Forwarded Requests per Backend'
                }
                {
                  name: 'PartSubTitle'
                  value: 'On 5-Minute aggregation'
                }
                {
                  name: 'ControlType'
                  value: 'FrameControlChart'
                }
                {
                  name: 'SpecificChart'
                  value: 'StackedArea'
                }
              ]
            }
          }
          '1': {
            position: {
              colSpan: 6
              rowSpan: 5
              x: 10
              y: 0
            }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                {
                  name: 'Scope'
                  value: {
                    resourceIds: [
                      appinsights.id
                    ]
                  }
                }
                {
                  name: 'Dimensions'
                  value: {
                    xAxis: {
                      name: 'Region'
                      type: 'string'
                    }
                    yAxis: [
                      {
                        name: 'Count'
                        type: 'long'
                      }
                    ]
                    splitBy: []
                    aggregation: 'Sum'
                  }
                }
                {
                  name: 'PartId'
                  value: guid(resourceGroup().name, 'part1')
                }
                {
                  name: 'Version'
                  value: '2.0'
                }
                {
                  name: 'TimeRange'
                  value: 'PT30M'
                }
                {
                  name: 'Query'
                  value: 'requests\r\n| summarize Count=count() by Region=tostring(customDimensions.Region)\r\n| render piechart'
                }
                {
                  name: 'PartTitle'
                  value: 'Handled requests per APIM Region'
                }
                {
                  name: 'PartSubTitle'
                  value: 'As load-balanced by Front Door'
                }
                {
                  name: 'ControlType'
                  value: 'FrameControlChart'
                }
                {
                  name: 'SpecificChart'
                  value: 'Pie'
                }
              ]
            }
          }
        }
      }
    }
  }
}