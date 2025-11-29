# GitHub Pages Deployment Guide

## Setup GitHub Secrets

1. **Go to your GitHub repository**
2. **Settings → Secrets and variables → Actions**
3. **Click "New repository secret"** and add these three secrets:

   | Name | Value |
   |------|-------|
   | `CALENDARIFIC_API_KEY` | Your Calendarific API key |
   | `FESTIVO_API_KEY` | Your Festivo API key |
   | `GOOGLE_CALENDAR_API_KEY` | Your Google Calendar API key |

## Enable GitHub Pages

1. **Settings → Pages**
2. **Source:** GitHub Actions
3. **Save**

## Deploy

### Automatic Deployment
- Push to `main` or `master` branch
- GitHub Actions will automatically build and deploy
- Check the **Actions** tab to see deployment progress

### Manual Deployment
- Go to **Actions** tab
- Select "Deploy to GitHub Pages" workflow
- Click "Run workflow"

## Local Development

For local development with API keys, create a `.env` file (gitignored):

```bash
# .env file content
CALENDARIFIC_API_KEY=your_key_here
FESTIVO_API_KEY=your_key_here
GOOGLE_CALENDAR_API_KEY=your_key_here
```

Then build with:

```bash
# Read from .env and build
flutter build web \
  --release \
  --dart-define=CALENDARIFIC_API_KEY=$(grep CALENDARIFIC_API_KEY .env | cut -d '=' -f2) \
  --dart-define=FESTIVO_API_KEY=$(grep FESTIVO_API_KEY .env | cut -d '=' -f2) \
  --dart-define=GOOGLE_CALENDAR_API_KEY=$(grep GOOGLE_CALENDAR_API_KEY .env | cut -d '=' -f2)
```

### Simpler local development (Windows PowerShell):

```powershell
# Create env.ps1 (gitignored)
$env:CALENDARIFIC_API_KEY="your_key"
$env:FESTIVO_API_KEY="your_key"
$env:GOOGLE_CALENDAR_API_KEY="your_key"

flutter build web --release `
  --dart-define=CALENDARIFIC_API_KEY=$env:CALENDARIFIC_API_KEY `
  --dart-define=FESTIVO_API_KEY=$env:FESTIVO_API_KEY `
  --dart-define=GOOGLE_CALENDAR_API_KEY=$env:GOOGLE_CALENDAR_API_KEY
```

## How It Works

### Compile-Time Environment Variables

The app uses Flutter's `--dart-define` to inject secrets at **build time**:

```dart
// lib/environment.dart
class Environment {
  static const String calendarificApiKey = String.fromEnvironment(
    'CALENDARIFIC_API_KEY',
    defaultValue: '',
  );
  // ...
}
```

### GitHub Actions Workflow

1. **Checkout code** from repository
2. **Get secrets** from GitHub Secrets
3. **Build** with `--dart-define` flags to inject secrets
4. **Deploy** static build to GitHub Pages

### Security

✅ **Secrets never appear in:**
- Source code
- Git history
- Build artifacts (they're compiled into the app)
- GitHub Actions logs (redacted automatically)

⚠️ **Important:**
- Anyone who downloads your compiled app can potentially extract the keys
- For production, use a backend API to proxy requests instead
- This approach is acceptable for public holiday APIs with usage limits

## Troubleshooting

### Build fails with "Environment variable not found"
- Check that secrets are configured in GitHub Settings
- Secret names must match exactly (case-sensitive)

### App loads but API calls fail
- Check browser console for errors
- Verify keys are valid and not expired
- Check API usage limits

### Changes not deploying
- Check Actions tab for build errors
- May take 2-3 minutes for deployment to complete
- Hard refresh browser (Ctrl+F5)

## Update base-href

If your repository is named differently than "whereabouts", update the GitHub Actions workflow:

```yaml
# Change this line in .github/workflows/deploy.yml
--base-href "/your-repo-name/"
```

## Repository Settings Must Match

Your GitHub Pages URL will be: `https://yourusername.github.io/whereabouts/`

Make sure:
- Repository must be public (or GitHub Pro for private)
- Repository name in workflow matches actual repo name
