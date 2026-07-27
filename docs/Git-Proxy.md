# Git Proxy

## Verify

```powershell
git config --global --get http.proxy
git config --global --get https.proxy
```

## Configure

```powershell
git config --global http.proxy http://192.168.113.13:8080
git config --global https.proxy http://192.168.113.13:8080
```

## Test

```powershell
git ls-remote origin
git push
```