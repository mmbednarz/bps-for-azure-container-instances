az login

# Change these parameters as needed
ACI_PERS_RESOURCE_GROUP=bps-for-aci

for value in $(az container list --resource-group $ACI_PERS_RESOURCE_GROUP --query "[].name" -o tsv)
do
    echo $value
    az container start --resource-group $ACI_PERS_RESOURCE_GROUP --name $value
done
