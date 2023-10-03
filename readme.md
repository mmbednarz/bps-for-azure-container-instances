# BPS for Azure Container Instances

bps-for-azure-container-instances is a solution that allows automated launch of a dev WEBCON BPS instance hosted as Azure Container Instances. 

The created services are available on the Internet, the solution is intended to make it easier to get to know the WEBCON BPS platform. Using the proposed configuration in a production environment is not recommended.

# Requirements:
- Access to create resources in an Azure tenant with an associated subscription.
- Bash shell with az cli

# Quick start:
1. Pull repo.
`git clone https://github.com/webcon-bps/bps-for-azure-container-instances.git`

2. Create Azure deployment.
`cd .\bps-for-azure-container-instances\`

Make sh files executable: `chmod u+x *.sh`

`./create.sh`

    Several Azure resources will be created: aci for SQL Server, SOLR, Caddy, bps-init, bps-portal, bps-service, storage account for persisting data. 
    The first run time is approximately 15 minutes (due to the need to download docker images and initialize the BPS databases). 

3. Once all services are launched, you can access the BPS Portal using the address displayed in Shell. The BPS Admin password is: `P@ssw0rd1`

4. Stop services
`./stop.sh`

5. Start services
`./start.sh`

6. Remove all services and persistent data
`./remove.sh`

# Port reservations
All services are available from internet, ports used:
- `8433` TCP for SQL Server
- `8983` TCP for SOLR
- `80` TCP for BPS Portal
- `80` TCP and `443` TCP for Caddy reverse proxy
- `8002` TCP and `8003` TCP for BPS Service

# Storage
Persistent data (SQL and SOLR databases) are placed in an Azure storage account share.
Stopping and restarting the services does not delete this data.

# User accounts
- sql login `sa`, password `P@ssw0rd`
- solr admin `solr`, password `123qweasdZXC`
- BPS Admin password `P@ssw0rd`