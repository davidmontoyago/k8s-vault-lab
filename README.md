# Prototype of auto unsealing Vault on K8s

## Build Vault initializer/unsealer image

```
cd vault-init && docker build . -t vault-init:latest
```

## Deploy it

```
kubectl apply -f vault.yaml
```
