param exists bool
param containerAppName string

resource existingApp 'Microsoft.App/containerApps@2023-04-01-preview' existing = if (exists) {
  name: containerAppName
}

output containers array = exists ? existingApp.properties.template.containers : []
