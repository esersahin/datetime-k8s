# macOS Network Performance Issue and Fix

## 🐛 Problem

When accessing Kind cluster via localhost on macOS, experiencing **5 second delay**.

### Symptoms

```bash
# Test
time curl -s http://api-go.local/health

# Result: ~5 seconds
curl -s http://api-go.local/health  0.01s user 0.01s system 0% cpu 5.025 total
```

- Every HTTP request returns with 5 second delay
- Fast from inside cluster (pod to pod): **0.00s**
- Slow from localhost to ingress: **5+ seconds**
- All `.local` domains are affected

## 🔍 Root Cause

**macOS DNS Resolver + IPv6 Timeout Issue**

For domains ending with `.local`, macOS:
1. Looks up IPv4 (A) record
2. Looks up IPv6 (AAAA) record - **5 second timeout here**
3. If IPv6 not found, falls back to IPv4

If `/etc/hosts` only has IPv4 (127.0.0.1), macOS still tries IPv6 lookup and **waits 5 seconds**.

### Why Only on macOS?

- Linux: Different DNS resolver behavior
- Docker Desktop macOS: Uses vpnkit, adds extra overhead
- Kind + macOS combination triggers the issue

## ✅ Solution: Add IPv6 Entry

### Automatic Fix (Makefile/deploy.sh)

Makefile and deploy.sh now automatically add IPv6:

```bash
make update-hosts
# or
./deploy.sh
```

Adds these lines to `/etc/hosts`:

```
127.0.0.1 api.local web.local api-go.local web-go.local
::1 api.local web.local api-go.local web-go.local  # ← This IPv6 entry fixes the 5 second issue
```

### Manual Fix

If not using Makefile:

```bash
sudo sh -c 'echo "::1 api.local web.local api-go.local web-go.local" >> /etc/hosts'
```

## 🧪 Test

Test after the fix:

```bash
# Before
time curl -s http://api-go.local/health
# Result: ~5 seconds ❌

# After adding IPv6
time curl -s http://api-go.local/health
# Result: ~0.01 seconds ✅
```

## 📊 Comparison

| Scenario | IPv4 Only | IPv4 + IPv6 |
|----------|-----------|-------------|
| First request | 5.02s ❌ | 0.01s ✅ |
| Second request | 5.01s ❌ | 0.01s ✅ |
| Inside cluster | 0.00s ✅ | 0.00s ✅ |

## 🔗 References

This is a known macOS issue:

1. **macOS DNS + IPv6 Timeout**:
   - Bonjour active for `.local` domains
   - IPv6 lookup timeout: 5 seconds
   - Solution: Add both IPv4 and IPv6 for each host

2. **Kubernetes GitHub Issues**:
   - [kubernetes/kubernetes#56903](https://github.com/kubernetes/kubernetes/issues/56903) - DNS intermittent delays of 5s
   - [kubernetes-sigs/kind#2280](https://github.com/kubernetes-sigs/kind/issues/2280) - Network setup delays

3. **Stack Overflow**:
   - [10-second delay for .local TLD in Mac OS X](https://superuser.com/questions/370559/10-second-delay-for-local-tld-in-mac-os-x-lion)
   - [Chrome Slow to Resolve /etc/hosts on macOS](https://superuser.com/questions/1189379/chrome-slow-to-resolve-etc-hosts-on-macos-os-x)

## ⚠️ Notes

- **This issue only affects local development** (Kind, Minikube, Docker Desktop)
- **No issue in production clusters (EKS, GKE, AKS)**
- Linux and Windows don't experience this issue
- Alternative solution: Use `.test` or `.dev` domains instead of `.local`

## 🎯 Summary

```bash
# Problem
127.0.0.1 api.local  # ← 5 second delay

# Solution
127.0.0.1 api.local  # IPv4
::1 api.local        # IPv6 ← This line fixes the 5 second issue!
```

When using `.local` domains on macOS, **always add IPv6 (::1) entry**!
