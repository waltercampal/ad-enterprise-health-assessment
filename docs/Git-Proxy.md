# Git Proxy

## Verify

```powershell
git config --global --get http.proxy
git config --global --get https.proxy
```

## Configure

```powershell
git config --global http.proxy http://10.10.10.10:8080
git config --global https.proxy http://10.10.10.10:8080
```

Replace `10.10.10.10:8080` with your organization's actual proxy address.

## Test

```powershell
git ls-remote origin
git push
```