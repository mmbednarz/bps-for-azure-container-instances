#!/bin/bash

if az account show > /dev/null 2>&1; then
  echo "You are already authenticated with Azure CLI."
else
  echo "You are not authenticated with Azure CLI. Logging in..."
  az login
fi

# Change these parameters as needed
ACI_PERS_RESOURCE_GROUP=bps-for-aci

for value in $(az container list --resource-group $ACI_PERS_RESOURCE_GROUP --query "[].name" -o tsv)
do
    echo $value
    az container stop --resource-group $ACI_PERS_RESOURCE_GROUP --name $value
done

