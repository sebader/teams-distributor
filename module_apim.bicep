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

resource api 'Microsoft.ApiManagement/service/apis@2020-06-01-preview' = {
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

resource operationGetbackend 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: '${api.name}/getbackend'
  properties: {
    displayName: 'GetBackend'
    method: 'GET'
    urlTemplate: '/getbackend'
  }
}

resource operationHealthz 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: '${api.name}/healthz'
  properties: {
    displayName: 'Healthz'
    method: 'HEAD'
    urlTemplate: '/healthz'
  }
}

resource getbackendPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2020-06-01-preview' = {
  name: '${operationGetbackend.name}/policy'
  properties: {
    format: 'xml'
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <return-response>\r\n      <set-status code="301" />\r\n      <set-header name="Location" exists-action="override">\r\n        <value>@{\r\n                    var backends = "{{backends}}".Split(\',\');\r\n                    var i = new Random(context.RequestId.GetHashCode()).Next(0, backends.Length);\r\n                    return backends[i];\r\n                }</value>\r\n      </set-header>\r\n    </return-response>\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
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

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2020-06-01-preview' = {
  name: '${apim.name}/${appInsights.name}'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsights.properties.InstrumentationKey
    }
    isBuffered: true
    resourceId: appInsights.id
  }
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2020-06-01-preview' = {
  name: '${apim.name}/applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
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

resource namedValueBackend 'Microsoft.ApiManagement/service/namedValues@2020-06-01-preview' = {
  name: '${apim.name}/backends'
  properties: {
    displayName: 'backends'
    value: backends
  }
}

// We only need the hostname, without the protocol
output apimHostname string = replace(apim.properties.gatewayUrl, 'https://', '')