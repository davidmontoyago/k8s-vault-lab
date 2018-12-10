# Prototype of auto unsealing Vault with Consul backend and dynamic app creds on K8s

## Deploy a Consul cluster
Use Consul as storage backend.

```
helm install --name consul --set='affinity=null,DisableHostNodeId=true,ImageTag=1.4.0' stable/consul
```

## Deploy Consul client on all nodes using a DaemonSet

The recommended practice is to have a Consul client running on every node and have the Vault backend point to the host IP using the K8s downward API.

Grab the gossip encryption key from the server.
```
kubectl exec consul-0 -- consul keyring -list
```

Store consul gossip key as a K8s secret so that the consul client can use it.
```
kubectl create secret generic consul-secrets --from-literal=gossip-encryption-key='<your_gossip_encryption_key>'
```

Deploy client.
```
kubectl apply -f consul/consul-client.yaml
```

## Build Vault initializer/unsealer image

```
cd vault-init && docker build . -t vault-init:latest
```

## Deploy Vault server

```
kubectl apply -f vault.yaml
```

## Deploy MySql database

Store MySql root password as a K8s secret. It will be consumed by the deployment resource (`sample-app/sample-db/mysql.yaml`).

```
kubectl create secret generic mysql-secrets --from-literal=mysql-root-password='<your_mysql_root_password>'
```

Deploy it.
```
kubectl apply -f sample-app/sample-db/mysql.yaml
```

## Configure Vault database engine

Redirect traffic to the pod from your localhost.
```
kubectl port-forward vault-0 8200
```
```
export VAULT_ADDR=http://localhost:8200
```

Check Vault status.
```
vault status
```

Login with the root token. The root token is exposed in the `vault-init` container logs for demo purposes.

```
vault login <your_vault_root_token>
```

Now actually configure the database engine.

```
vault secrets enable database
```

Configure database engine in Vault. Only `didb` role will be allowed to consume the `didb-mysql-database` database.
```
MYSQL_POD_HOST=$(kubectl get pods -l app=mysql -o jsonpath='{.items[0].status.podIP}')

vault write database/config/didb-mysql-database \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp($MYSQL_POD_HOST:3306)/" \
    allowed_roles="didb" \
    username="root" \
    password="<your_mysql_root_password>"
```

Create `didb` role.
```
vault write database/roles/didb \
    db_name=didb-mysql-database \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON didb.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"
```

Confirm credentials can be generated.

```
vault read -format json database/creds/didb
```

Finally, create Vault policy with read access for the `database/creds/didb` path.

```
vault policy write didb-policy ./vault-config/db-creds-policy.hcl
```

## Create service account

The service account will be used by the pods to authenticate against Vault.

```
kubectl apply -f ./sample-app/sample-db/mysql-vault-service-account.yaml
```

## Configure Vault Kubernetes authentication

```
vault auth enable kubernetes
```

Create auth config to allow the pods to auth against Vault using the service account JWT token. Pods authenticating with the service account `mysql-didb-vault` will be granted the `didb-policy` created previously.
```
VAULT_SA_NAME=$(kubectl get sa mysql-didb-vault -o jsonpath="{.secrets[*]['name']}")
SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)
SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
K8S_HOST=<your_k8s_host>

vault write auth/kubernetes/config \
  token_reviewer_jwt="$SA_JWT_TOKEN" \
  kubernetes_host="https://$K8S_HOST:443" \
  kubernetes_ca_cert="$SA_CA_CRT"

vault write auth/kubernetes/role/didb \
  bound_service_account_names=mysql-didb-vault \
  bound_service_account_namespaces=default \
  policies=didb-policy \
  ttl=24h
```

## Deploy sample app

```
kubectl apply -f ./sample-app/sample-app.yaml
```
