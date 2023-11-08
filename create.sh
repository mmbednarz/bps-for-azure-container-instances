#!/bin/bash

if az account show > /dev/null 2>&1; then
  echo "You are already authenticated with Azure CLI."
else
  echo "You are not authenticated with Azure CLI. Logging in..."
  az login
fi

#create random id
export RANDOM_ID=$RANDOM

# Change these parameters as needed
export ACI_PERS_RESOURCE_GROUP=bps-for-aci
export ACI_PERS_STORAGE_ACCOUNT_NAME=bpsfiles$RANDOM_ID
export ACI_PERS_LOCATION=polandcentral
export ACI_PERS_SHARE_NAME_SQL=sqlfiles
export ACI_PERS_SHARE_NAME_SOLR=solrfiles

#$RANDOM_ID
#$ACI_PERS_RESOURCE_GROUP

# Create RG
az group create \
    --location $ACI_PERS_LOCATION \
    --name $ACI_PERS_RESOURCE_GROUP

# Create the storage account with the parameters
az storage account create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name $ACI_PERS_STORAGE_ACCOUNT_NAME \
    --location $ACI_PERS_LOCATION \
    --sku Standard_LRS

# Create the file share
az storage share create \
  --name $ACI_PERS_SHARE_NAME_SQL \
  --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME

az storage share create \
--name $ACI_PERS_SHARE_NAME_SOLR \
--account-name $ACI_PERS_STORAGE_ACCOUNT_NAME


STORAGE_KEY=$(az storage account keys list --resource-group $ACI_PERS_RESOURCE_GROUP --account-name $ACI_PERS_STORAGE_ACCOUNT_NAME --query "[0].value" --output tsv)
#echo $STORAGE_KEY

#sql server
az container create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name 1-sql-server$RANDOM_ID \
    --image webconbps/sqlserver:2022 \
    --dns-name-label sql-server$RANDOM_ID \
    --ports 1433 \
    --cpu 1 \
    --memory 2 \
    --ip-address public \
    --azure-file-volume-account-name $ACI_PERS_STORAGE_ACCOUNT_NAME \
    --azure-file-volume-account-key $STORAGE_KEY \
    --azure-file-volume-share-name $ACI_PERS_SHARE_NAME_SQL \
    --azure-file-volume-mount-path /var/opt/mssql/ \
    --environment-variables ACCEPT_EULA=Y MSSQL_SA_PASSWORD=P@ssw0rd \
    --os-type Linux \
    --restart-policy OnFailure


#solr
az container create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name 2-search-server$RANDOM_ID \
    --image webconbps/search:2023.1.2.99 \
    --dns-name-label search-server$RANDOM_ID \
    --ports 8983 \
    --cpu 1 \
    --memory 1.5 \
    --ip-address public \
    --azure-file-volume-account-name $ACI_PERS_STORAGE_ACCOUNT_NAME \
    --azure-file-volume-account-key $STORAGE_KEY \
    --azure-file-volume-share-name $ACI_PERS_SHARE_NAME_SOLR \
    --azure-file-volume-mount-path /var/solr/ \
    --environment-variables SOLR_HEAP=1g \
    --command-line "/bin/bash -c '/opt/bps-solr/scripts/run-precreate-cores.sh'" \
    --os-type Linux \
    --restart-policy OnFailure

#bps init
az container create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name 3-bps-init$RANDOM_ID \
    --image webconbps/init:2023.1.2.99-windowsservercore-ltsc2022 \
    --dns-name-label bps-init$RANDOM_ID \
    --cpu 1 \
    --memory 1 \
    --environment-variables sqlhostname=sql-server$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io \
        sqlport=1433 \
        solrhostname=search-server$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io \
        solrport=8983 \
        hostname=sql-server$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io \
    --os-type Windows \
    --restart-policy OnFailure


#wait for init end
aci_name="3-bps-init$RANDOM_ID"

# Interval between checks in seconds (e.g., 60 seconds)
interval=60

while true; do
    aci_status=$(az container show --name "$aci_name" --resource-group "$ACI_PERS_RESOURCE_GROUP" --query 'containers[0].instanceView.currentState.state' --output tsv)

    if [ "$aci_status" == "Terminated" ]; then
        aci_exit_code=$(az container show --name "$aci_name" --resource-group "$ACI_PERS_RESOURCE_GROUP" --query 'containers[0].instanceView.currentState.exitCode' --output tsv)

        if [ "$aci_exit_code" -eq 0 ]; then
            echo "$aci_name ended with success (Exit Code: $aci_exit_code)"
            break
        else
            echo "$aci_name ended with a non-zero exit code: $aci_exit_code"
        fi
    else
        echo "$aci_name is not in a terminated state. Checking again in $interval seconds..."
        sleep "$interval"  # Wait for the specified interval before checking again
    fi
done


#bps-service
az container create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name 4-bps-service$RANDOM_ID \
    --image webconbps/service:2023.1.2.99-windowsservercore-ltsc2022 \
    --dns-name-label bps-service$RANDOM_ID \
    --cpu 1 \
    --memory 1 \
    --ports 8002 8003 \
    --environment-variables \
        Configuration__BpsDbConfigRaw="Server=sql-server$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io;Database=BPS_Config;User ID=sa;Password=P@ssw0rd" \
        Configuration__ExternalWebService__Host=bps-service$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io \
        Configuration__ExternalWebService__LicenseServicePort=8002 \
        Configuration__ExternalWebService__Port=8003 \
        Configuration__BpsSelfHost=true \
        Configuration__Init__DoInit=true \
        Configuration__Init__WebService__LicenseServicePort=8002 \
        Configuration__Init__WebService__Port=8003 \
        Configuration__Init__ServiceRoles__LicenseService=true \
        Configuration__Init__ServiceRoles__BasicFeatures=true \
        Configuration__Init__ServiceRoles__SolrIndexing=true \
    --os-type Windows \
    --restart-policy OnFailure


#bps portal
az container create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name 5-bps-portal$RANDOM_ID \
    --image webconbps/portal:2023.1.2.99-windowsservercore-ltsc2022 \
    --dns-name-label bps-portal$RANDOM_ID \
    --cpu 1 \
    --memory 1.5 \
    --ports 80 \
    --environment-variables \
        App__ConfigConnection__Value="Server=sql-server$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io,1433;Database=BPS_Config;User ID=sa;Password=P@ssw0rd" \
        App__LogsConnection__Value="Server=sql-server$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io,1433;Database=BPS_Config;User ID=sa;Password=P@ssw0rd" \
        App__IISIntegration=false \
        App__ForceHttpsOnProxy=true \
        App__Kestler__Port=80 \
        App__Kestler__UseSSL=false \
        App__Kestler__Protocol=http \
        App__LogLevel__Value=Warn \
    --os-type Windows \
    --restart-policy OnFailure

#reverse proxy
az container create \
    --resource-group $ACI_PERS_RESOURCE_GROUP \
    --name 6-caddy-proxy$RANDOM_ID \
    --image caddy \
    --dns-name-label bps$RANDOM_ID \
    --ports 443 80 \
    --cpu 1 \
    --memory 1 \
    --ip-address public \
    --command-line "caddy reverse-proxy --from bps$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io --to bps-portal$RANDOM_ID.$ACI_PERS_LOCATION.azurecontainer.io:80" \
    --os-type Linux \
    --restart-policy OnFailure

url="https://$( \
    az container show \
        --resource-group $ACI_PERS_RESOURCE_GROUP \
        --name 6-caddy-proxy$RANDOM_ID \
        --query "ipAddress.fqdn" \
        --output tsv
    )/health"  # Replace with your desired URL
max_attempts=600            # Number of maximum attempts
sleep_interval=5           # Sleep interval between attempts (in seconds)

attempt=0

while [ $attempt -lt $max_attempts ]; do
    http_status=$(curl -s -o /dev/null -w "%{http_code}" $url)
    
    if [ "$http_status" -eq 200 ]; then
        echo "HTTP status is 200 OK. Exiting."
        break
    else
        echo "HTTP status is $http_status. Retrying in $sleep_interval seconds..."
        sleep $sleep_interval
        attempt=$((attempt + 1))
    fi
done

url="https://$( \
    az container show \
        --resource-group $ACI_PERS_RESOURCE_GROUP \
        --name 6-caddy-proxy$RANDOM_ID \
        --query "ipAddress.fqdn" \
        --output tsv
    )"

echo "Your BPS instance is redy, go to: $url" 
echo "BPS Admin Password is "P@ssw0rd"."