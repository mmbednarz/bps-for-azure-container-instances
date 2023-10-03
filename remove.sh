#!/bin/bash

if az account show > /dev/null 2>&1; then
  echo "You are already authenticated with Azure CLI."
else
  echo "You are not authenticated with Azure CLI. Logging in..."
  az login
fi

# Change these parameters as needed
export ACI_PERS_RESOURCE_GROUP=bps-for-aci

az group delete --name $ACI_PERS_RESOURCE_GROUP --yes