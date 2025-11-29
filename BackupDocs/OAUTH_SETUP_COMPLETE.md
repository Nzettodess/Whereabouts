# 🔐 Complete OAuth & Domain Setup Guide

## Overview
When deploying a Flutter Firebase app with Google Sign-In to a custom domain (like GitHub Pages), you need to configure **3 different places**. Missing any one will cause authentication to fail.

---

## 📍 The 3 Required Configurations

### ✅ 1. Firebase Console - Authorized Domains
### ✅ 2. Google Cloud Console - OAuth Consent Screen
### ✅ 3. Google Cloud Console - OAuth Client Credentials

---

## 1️⃣ Firebase Console - Authorized Domains

**Purpose:** Tell Firebase which domains are allowed to use Firebase Authentication.

**Location:** 
- https://console.firebase.google.com/
- Select your project
- **Authentication → Settings tab**
- Scroll to **Authorized domains**

**What to Add:**
```
localhost                              (for local development)
yourproject.firebaseapp.com           (auto-added by Firebase)
yourproject.web.app                   (auto-added by Firebase)
yourusername.github.io                (your GitHub Pages domain)
```

**Example for this project:**
```
localhost
whereabouts-510db.firebaseapp.com
whereabouts-510db.web.app
nzettodess.github.io
```

**How to Add:**
1. Click **Add domain**
2. Enter domain (e.g., `nzettodess.github.io`)
3. Click **Add**

**⚠️ Common Mistake:**
- ❌ Forgetting to add GitHub Pages domain
- ❌ Adding `https://` (should be just the domain)

---

## 2️⃣ Google Cloud Console - OAuth Consent Screen

**Purpose:** Declare which domains will show on the OAuth consent screen users see when logging in.

**Location:**
- https://console.cloud.google.com/
- Select your Firebase project (same project!)
- **APIs & Services → OAuth consent screen**
- Click **Edit App**

**What to Add:**

**Authorized domains section:**
```
yourproject.firebaseapp.com
yourusername.github.io
```

**Example for this project:**
```
whereabouts-510db.firebaseapp.com
nzettodess.github.io
```

**How to Add:**
1. Scroll to **Authorized domains**
2. Click **+ Add Domain**
3. Enter domain (e.g., `nzettodess.github.io`)
4. Enter each domain separately
5. Click **Save and Continue**

**⚠️ Common Mistakes:**
- ❌ Using root domains (`github.io`, `firebaseapp.com`) → Won't work for public hosts
- ❌ Adding `https://` or paths
- ✅ Use **full subdomain** (e.g., `nzettodess.github.io`)

---

## 3️⃣ Google Cloud Console - OAuth Client Credentials

**Purpose:** Specify exactly which URLs can initiate OAuth login and where OAuth can redirect after login.

**Location:**
- https://console.cloud.google.com/
- Select your Firebase project
- **APIs & Services → Credentials**
- Find "Web client (auto created by Google Service)"
- Click **Edit** (pencil icon)

**What to Add:**

### **Authorized JavaScript origins:**
These are the URLs where your app runs:
```
http://localhost
http://localhost:5000
https://yourproject.firebaseapp.com
https://yourusername.github.io
```

**Example for this project:**
```
http://localhost
http://localhost:5000
https://whereabouts-510db.firebaseapp.com
https://nzettodess.github.io
```

### **Authorized redirect URIs:**
These are the callback URLs after OAuth completes:
```
http://localhost/__/auth/handler
https://yourproject.firebaseapp.com/__/auth/handler
https://yourusername.github.io/__/auth/handler
https://yourusername.github.io/YourRepoName/__/auth/handler
```

**Example for this project:**
```
http://localhost/__/auth/handler
https://whereabouts-510db.firebaseapp.com/__/auth/handler
https://nzettodess.github.io/__/auth/handler
https://nzettodess.github.io/Whereabouts/__/auth/handler
```

**How to Add:**
1. Click **+ Add URI** under each section
2. Enter each URI one at a time
3. Click **Save** at the bottom

**⚠️ Common Mistakes:**
- ❌ Missing the `/__/auth/handler` path
- ❌ Forgetting both the base domain AND the repo path versions
- ❌ Typo in repository name (case-sensitive!)

---

## 📋 Complete Checklist for New Domain

When adding a new deployment domain (e.g., deploying to a new host):

### 1. Firebase Console
- [ ] Add domain to Authentication → Settings → Authorized domains

### 2. Google Cloud - OAuth Consent Screen
- [ ] Add domain to OAuth consent screen → Authorized domains

### 3. Google Cloud - OAuth Client
- [ ] Add `https://yourdomain.com` to Authorized JavaScript origins
- [ ] Add `https://yourdomain.com/__/auth/handler` to Authorized redirect URIs
- [ ] If deployed to a subdirectory, also add `https://yourdomain.com/path/__/auth/handler`

### 4. Wait & Test
- [ ] Wait 5-10 minutes for changes to propagate
- [ ] Clear browser cache or use incognito
- [ ] Test login

---

## 🔍 Troubleshooting Guide

### Error: "This domain is not authorized for OAuth operations"
**Missing:** Firebase Console → Authorized domains
**Fix:** Add your domain to Firebase Authentication Settings

### Error: "401: invalid_client" or "unauthorized domain"
**Missing:** OAuth Consent Screen → Authorized domains
**Fix:** Add your domain to Google Cloud OAuth consent screen

### Error: "redirect_uri_mismatch"
**Missing:** OAuth Client → Authorized redirect URIs
**Fix:** Add the exact redirect URI to OAuth client credentials

### Login popup opens then immediately closes
**Missing:** OAuth Client → Authorized JavaScript origins
**Fix:** Add your domain to JavaScript origins

---

## 🎯 Quick Reference

| Configuration | URL Format | Example |
|--------------|------------|---------|
| **Firebase Domains** | `yourdomain.com` | `nzettodess.github.io` |
| **OAuth Consent Domains** | `yourdomain.com` | `nzettodess.github.io` |
| **JavaScript Origins** | `https://yourdomain.com` | `https://nzettodess.github.io` |
| **Redirect URIs** | `https://yourdomain.com/__/auth/handler` | `https://nzettodess.github.io/__/auth/handler` |

---

## 💡 Key Points to Remember

1. **Three separate places** need configuration - missing any one will cause errors
2. **Full subdomain** for Firebase/GitHub (e.g., `nzettodess.github.io`, not `github.io`)
3. **Firebase domain** (`yourproject.firebaseapp.com`) must be included everywhere
4. **Case-sensitive** URLs - `Whereabouts` ≠ `whereabouts`
5. **No trailing slashes** in domains or origins
6. **Changes take time** - wait 5-10 minutes after saving
7. **Localhost** is already configured by default for development

---

## 🚀 For This Project Specifically

### Firebase Console
```
localhost
whereabouts-510db.firebaseapp.com
whereabouts-510db.web.app
nzettodess.github.io
```

### OAuth Consent Screen
```
whereabouts-510db.firebaseapp.com
nzettodess.github.io
```

### OAuth Client - Origins
```
http://localhost
http://localhost:5000
https://whereabouts-510db.firebaseapp.com
https://nzettodess.github.io
```

### OAuth Client - Redirects
```
http://localhost/__/auth/handler
https://whereabouts-510db.firebaseapp.com/__/auth/handler
https://nzettodess.github.io/__/auth/handler
https://nzettodess.github.io/Whereabouts/__/auth/handler
```

---

**Remember:** All three configurations must be complete for Google Sign-In to work! ✅
