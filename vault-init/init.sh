#!/bin/sh

VAULT_ADDR="http://localhost:8200"

INITIALIZED=$(curl $VAULT_ADDR/v1/sys/init | jq '.initialized')

if [ "$INITIALIZED" = "false" ]
then
  echo "initliazing vault..."
  UNSEAL_KEY=$(curl --request POST --data '{"secret_shares": 1, "secret_threshold": 1}' $VAULT_ADDR/v1/sys/init | jq '.keys_base64[0]')

  echo "unseal key is $UNSEAL_KEY... sshhhhh this is a secret"

  echo "unsealing vault..."
  curl --request POST --data '{"key": '$UNSEAL_KEY'}' $VAULT_ADDR/v1/sys/unseal | jq

  tail -f /dev/null
fi

curl $VAULT_ADDR/v1/sys/health | jq
