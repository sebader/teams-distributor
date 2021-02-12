param prefix string
param location string
param publisherEmail string
param publisherName string

param backends string

param applicationInsightsName string

resource apim 'Microsoft.ApiManagement/service@2020-06-01-preview' = {
  name: '${prefix}${location}apim'
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName

    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'true'
    }
  }
}

resource apiGetbackend 'Microsoft.ApiManagement/service/apis@2020-06-01-preview' = {
  name: '${apim.name}/getbackend'
  properties: {
    apiRevision: '1'
    displayName: 'GetBackend'
    subscriptionRequired: false
    protocols: [
      'https'
    ]
    path: ''
  }
}

resource apiHealthz 'Microsoft.ApiManagement/service/apis@2020-06-01-preview' = {
  name: '${apim.name}/apimhealthz'
  properties: {
    apiRevision: '1'
    displayName: 'APIM Healthz'
    subscriptionRequired: false
    protocols: [
      'https'
    ]
    path: 'healthz'
  }
}

resource operationGetbackend 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: '${apiGetbackend.name}/getbackend'
  properties: {
    displayName: 'GetBackend'
    method: 'GET'
    urlTemplate: '/'
  }
}

resource operationHealthz 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: '${apiHealthz.name}/apimhealth'
  properties: {
    displayName: 'ApimHealth'
    method: 'HEAD'
    urlTemplate: '/'
  }
}

resource getbackendPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2020-06-01-preview' = {
  name: '${operationGetbackend.name}/policy'
  properties: {
    format: 'xml'
    // The 'backends' parameter gets injected into the policy here (scroll further to the right)
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <return-response>\r\n      <set-status code="302" />\r\n      <set-header name="Location" exists-action="override">\r\n        <value>@{\r\n                    var backends = "${backends}".Split(\',\');\r\n                    var i = new Random(context.RequestId.GetHashCode()).Next(0, backends.Length);\r\n                    return backends[i];\r\n                }</value>\r\n      </set-header>\r\n    </return-response>\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
  }
}

resource healthzPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2020-06-01-preview' = {
  name: '${operationHealthz.name}/policy'
  properties: {
    format: 'xml'
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <return-response>\r\n      <set-status code="200" />\r\n    </return-response>\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
  }
}

// Section: Logging

resource namedValueAppInsightsKey 'Microsoft.ApiManagement/service/namedValues@2020-06-01-preview' = {
  name: '${apim.name}/logger-credentials'
  properties: {
    displayName: 'logger-credentials'
    value: appInsights.properties.InstrumentationKey
    secret: true
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2020-06-01-preview' = {
  name: '${apim.name}/${appInsights.name}'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: '{{logger-credentials}}'
    }
    isBuffered: true
    resourceId: appInsights.id
  }
}

resource apiGetbackendDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2020-06-01-preview' = {
  name: '${apiGetbackend.name}/applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    loggerId: apimLogger.id
    frontend: {
      response: {
        headers: [
          'location'
        ]
      }
    }
  }
}

// Use AppInsights which was created outside of this module
resource appInsights 'Microsoft.Insights/components@2018-05-01-preview' existing = {
  name: applicationInsightsName
}

// We only need the hostname, without the protocol
output apimHostname string = replace(apim.properties.gatewayUrl, 'https://', '')