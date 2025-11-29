# 🌐 How to Host a Flutter Web App on GitHub Pages

## 📖 Understanding Flutter Web Hosting

### What is Flutter Web?
Flutter can compile your app to **JavaScript and HTML** that runs in web browsers. When you build for web, Flutter creates:
- `index.html` - Main HTML file
- `main.dart.js` - Your compiled Dart code as JavaScript
- `flutter.js` - Flutter web engine
- Assets (images, fonts, etc.)

### How GitHub Pages Works
GitHub Pages is a **static website hosting** service. It can host any static files (HTML, CSS, JS). Perfect for Flutter web apps!

---

## ✅ Your Setup is COMPLETE!

I've already configured everything for you. Here's what's ready:

### 1. **GitHub Actions Workflow** ✅
Location: `.github/workflows/deploy.yml`

This workflow automatically:
1. Builds your Flutter app for web → `flutter build web`
2. Injects your API keys from GitHub Secrets
3. Uploads the build to GitHub Pages
4. Deploys it live

### 2. **Build Configuration** ✅
```yaml
flutter build web \
  --release \                      # Production build
  --web-renderer canvaskit \       # Best compatibility
  --base-href "/whereabouts/" \    # Matches your repo name
  --dart-define=CALENDARIFIC_API_KEY=$CALENDARIFIC_API_KEY
```

---

## 🚀 How to Deploy (3 Simple Steps)

### Step 1: Push Your Code to GitHub
```bash
cd c:\Users\Nzettodess\Downloads\whereabouts

# Add all files
git add .

# Commit
git commit -m "Add GitHub Pages deployment"

# Push (replace 'main' with 'master' if needed)
git push origin main
```

### Step 2: Enable GitHub Pages
1. Go to your GitHub repository
2. Click **Settings** (top right)
3. Click **Pages** (left sidebar)
4. Under "Build and deployment":
   - **Source**: Select **"GitHub Actions"**
5. Click **Save**

### Step 3: Watch Deployment
1. Go to **Actions** tab in your repository
2. You'll see "Deploy to GitHub Pages" running
3. Wait 2-3 minutes
4. ✅ Done! Your app is live!

---

## 🌍 Accessing Your Live App

Your app will be available at:
```
https://[your-github-username].github.io/whereabouts/
```

**Example:**
- If your username is `john`, the URL is:
- `https://john.github.io/whereabouts/`

---

## 🔧 How It Works (Behind the Scenes)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. You push code to GitHub                                 │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. GitHub Actions starts automatically                     │
│    - Checks out your code                                   │
│    - Installs Flutter                                       │
│    - Runs: flutter pub get                                  │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Builds your Flutter web app                             │
│    - Compiles Dart → JavaScript                             │
│    - Injects API keys from GitHub Secrets                   │
│    - Creates: build/web/                                    │
│      ├── index.html                                         │
│      ├── main.dart.js                                       │
│      └── flutter.js                                         │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Uploads to GitHub Pages                                 │
│    - Takes everything from build/web/                       │
│    - Deploys to: yourusername.github.io/whereabouts/        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Your app is LIVE! 🎉                                     │
│    - Anyone can access it via URL                           │
│    - No server needed - it's static files                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 📱 What Gets Deployed

When GitHub Actions runs `flutter build web`, it creates:

```
build/web/
├── index.html              ← Entry point
├── flutter.js              ← Flutter engine
├── main.dart.js            ← Your app (compiled)
├── assets/                 ← Images, fonts, etc.
│   ├── logo.png
│   └── google_logo.png
├── canvaskit/              ← Rendering engine
└── icons/                  ← Favicon, PWA icons
```

All of this gets deployed to GitHub Pages as **static files**.

---

## 🎯 Important Notes

### Repository Name Matters!
Your workflow has:
```yaml
--base-href "/whereabouts/"
```

This means:
- ✅ Repository name: `whereabouts` → Works perfectly
- ❌ Repository name: `my-app` → Need to change workflow to `--base-href "/my-app/"`

### Make Repository Public
GitHub Pages is **free for public repositories**. Private repos need GitHub Pro.

### Build Time
First deployment takes ~3-5 minutes. Subsequent ones are faster (~2 minutes).

---

## 🛠️ Testing Locally (Optional)

If you want to test the web build locally before deploying:

```bash
# Build for web
flutter build web --release \
  --dart-define=CALENDARIFIC_API_KEY=your_key \
  --dart-define=FESTIVO_API_KEY=your_key \
  --dart-define=GOOGLE_CALENDAR_API_KEY=your_key

# Serve locally (requires Python)
cd build/web
python -m http.server 8000

# Or use Flutter's built-in server
flutter run -d chrome
```

Then open: `http://localhost:8000`

---

## 🔍 Troubleshooting

### "Actions" tab shows error
**Solution:**
1. Click on the failed workflow
2. Read the error message
3. Common issues:
   - Missing GitHub Secrets → Add them in Settings → Secrets
   - Wrong branch name → Check if it's `main` or `master`

### App shows blank page
**Solution:**
1. Open browser console (F12)
2. Check for errors
3. Common issues:
   - Wrong `base-href` → Update in workflow file
   - Missing API keys → Check GitHub Secrets

### 404 Error
**Solution:**
- Wait 2-3 minutes after first deployment
- Hard refresh: `Ctrl + F5`
- Check GitHub Pages is set to "GitHub Actions"

---

## 🎉 You're Ready!

Your Flutter app is **already configured** for GitHub Pages. Just:
1. **Push** your code
2. **Enable** GitHub Pages
3. **Wait** for deployment
4. **Share** your app URL!

No additional configuration needed! 🚀
