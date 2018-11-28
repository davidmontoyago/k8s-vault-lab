#!/bin/sh

VAULT_ADDR="http://localhost:8200"

INITIALIZED=$(curl $VAULT_ADDR/v1/sys/init | jq '.initialized')

if [ "$INITIALIZED" = "false" ]
then
  echo "initializing vault..."
  INIT_RESPONSE=$(curl --request POST --data '{"secret_shares": 1, "secret_threshold": 1}' $VAULT_ADDR/v1/sys/init)

  UNSEAL_KEY=$(echo $INIT_RESPONSE | jq '.keys_base64[0]')
  echo "unseal key is $UNSEAL_KEY... sshhhhh this is a secret"

  ROOT_TOKEN=$(echo $INIT_RESPONSE | jq '.root_token')
  echo "root token is $ROOT_TOKEN... this is a secret too!"

  echo "unsealing vault..."
  curl --request POST --data '{"key": '$UNSEAL_KEY'}' $VAULT_ADDR/v1/sys/unseal | jq

  tail -f /dev/null
fi

curl $VAULT_ADDR/v1/sys/health | jq
