param prefix string
param location string
param publisherEmail string
param publisherName string

param backends string
param useTableStorage bool

param applicationInsightsName string

param sasTokenStart string = utcNow('yyyy-MM-ddTHH:mm:ssZ')
param sasTokenExpiry string = dateTimeAdd(utcNow('u'), 'P2Y', 'yyyy-MM-ddTHH:mm:ssZ') // Expries in 2 years from deployment time


resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01'  = if(useTableStorage) {
  name: take('stg${location}${replace(guid(resourceGroup().name, location, 'stg'), '-', '')}', 22) // build unique storage account name from 'stg', location and guid()
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
    tier: 'Standard'
  }
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

var tableName = 'Urls'

resource table 'Microsoft.Storage/storageAccounts/tableServices/tables@2019-06-01' = if(useTableStorage) {
  name: '${storageAccount.name}/default/${tableName}'
}

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

// Based on the parameter useTableStorage either this operation is being created...
resource operationGetbackend 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = if(!useTableStorage)  {
  name: '${apiGetbackend.name}/getbackendfrompolicy'
  properties: {
    displayName: 'Get Backend From Policy'
    method: 'GET'
    urlTemplate: '/'
  }
}
// ... or this operation is being used. This one will retrieve the backend URLs from the Table storage.
resource operationGetbackendFromTable 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = if(useTableStorage) {
  name: '${apiGetbackend.name}/getbackendfromtable'
  properties: {
    displayName: 'Get Backend From Table Storage'
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

resource getbackendPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2020-06-01-preview' = if(!useTableStorage) {
  name: '${operationGetbackend.name}/policy'
  properties: {
    format: 'xml'
    // The 'backends' parameter gets injected into the policy here (scroll further to the right)
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <return-response>\r\n      <set-status code="302" />\r\n      <set-header name="Location" exists-action="override">\r\n        <value>@{\r\n                    var backends = "${backends}".Split(\',\');\r\n                    var i = new Random(context.RequestId.GetHashCode()).Next(0, backends.Length);\r\n                    return backends[i];\r\n                }</value>\r\n      </set-header>\r\n    </return-response>\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
  }
}

resource getbackendFromTablePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2020-06-01-preview' = if(useTableStorage) {
  name: '${operationGetbackendFromTable.name}/policy'
  dependsOn: [
    namedValueTableUrl
    namedValueTableSasToken
  ]
  properties: {
    format: 'xml'
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <!-- Make outbound request to the table API which holds the list of backend URLs -->\r\n    <send-request mode="new" response-variable-name="tableApiResponse" timeout="20" ignore-error="true">\r\n      <set-url>@("{{table-url}}?{{table-sas-token}}&amp;$select=url")</set-url>\r\n      <set-method>GET</set-method>\r\n      <set-header name="Accept" exists-action="override">\r\n        <value>application/json;odata=nometadata</value>\r\n      </set-header>\r\n    </send-request>\r\n    <set-method>GET</set-method>\r\n    <return-response>\r\n      <set-status code="302" />\r\n      <set-header name="Location" exists-action="override">\r\n        <value>@{\r\n                    try\r\n                    {\r\n                        var urls = ((IResponse) context.Variables["tableApiResponse"]).Body.As&lt;JObject&gt;()["value"];\r\n                        // Generate random rowKey\r\n                        var rowKey = new Random(context.RequestId.GetHashCode()).Next(0, urls.Count());\r\n                        return (string)urls[rowKey]["url"];\r\n                    }\r\n                    catch (Exception e)\r\n                    {\r\n                        // If something failed, it is usually because of an transient error. Then we just send the user to the same URL again to retry.\r\n                        return "/";\r\n                    }\r\n                }</value>\r\n      </set-header>\r\n    </return-response>\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
  }
}

resource healthzPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2020-06-01-preview' = {
  name: '${operationHealthz.name}/policy'
  properties: {
    format: 'xml'
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <return-response>\r\n      <set-status code="200" />\r\n    </return-response>\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
  }
}

// Section: named values for Table storage backend
resource namedValueTableUrl 'Microsoft.ApiManagement/service/namedValues@2020-06-01-preview' = if(useTableStorage) {
  name: '${apim.name}/table-url'
  properties: {
    displayName: 'table-url'
    value: '${storageAccount.properties.primaryEndpoints.table}${tableName}'
  }
}

// Table storage sas token properties
var accountSasProperties = {
  signedServices: 't' // only valid on Table endpoint
  signedPermission: 'rl' // Permissions: read and list
  signedResourceTypes: 'o' // object-level
  signedStart: sasTokenStart
  signedExpiry: sasTokenExpiry
}

resource namedValueTableSasToken 'Microsoft.ApiManagement/service/namedValues@2020-06-01-preview' = if(useTableStorage) {
  name: '${apim.name}/table-sas-token'
  properties: {
    displayName: 'table-sas-token'
    value: listAccountSas(storageAccount.name, storageAccount.apiVersion, accountSasProperties).accountSasToken
    secret: true
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