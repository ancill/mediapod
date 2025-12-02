# Security Guidelines

## Credential Management

### Never Hardcode Credentials

**NEVER** commit the following to source control:
- ImgProxy signing keys (`keyHex`, `saltHex`)
- API authentication tokens
- Production API URLs
- Any other secrets or credentials

### Use Environment Variables

Configure your application using environment variables:

```bash
# Flutter (using --dart-define)
flutter run \
  --dart-define=MEDIAPOD_API_URL=https://your-api.example.com \
  --dart-define=MEDIAPOD_IMGPROXY_URL=https://your-imgproxy.example.com \
  --dart-define=MEDIAPOD_IMGPROXY_KEY=your-key-hex \
  --dart-define=MEDIAPOD_IMGPROXY_SALT=your-salt-hex

# Dart CLI
MEDIAPOD_API_URL=https://your-api.example.com \
MEDIAPOD_IMGPROXY_URL=https://your-imgproxy.example.com \
MEDIAPOD_IMGPROXY_KEY=your-key-hex \
MEDIAPOD_IMGPROXY_SALT=your-salt-hex \
dart run your_app.dart
```

### In Your App Code

```dart
class AppConfig {
  static const apiUrl = String.fromEnvironment('MEDIAPOD_API_URL');
  static const imgproxyUrl = String.fromEnvironment('MEDIAPOD_IMGPROXY_URL');
  static const imgproxyKey = String.fromEnvironment('MEDIAPOD_IMGPROXY_KEY');
  static const imgproxySalt = String.fromEnvironment('MEDIAPOD_IMGPROXY_SALT');
}
```

## Environment Variables Reference

| Variable | Description | Required |
|----------|-------------|----------|
| `MEDIAPOD_API_URL` | Base URL for the Mediapod API | Yes |
| `MEDIAPOD_IMGPROXY_URL` | Base URL for imgproxy service | Yes (for image optimization) |
| `MEDIAPOD_IMGPROXY_KEY` | Hex-encoded imgproxy signing key | Yes (for signed URLs) |
| `MEDIAPOD_IMGPROXY_SALT` | Hex-encoded imgproxy signing salt | Yes (for signed URLs) |
| `MEDIAPOD_VOD_URL` | Base URL for VOD streaming | Yes (for video playback) |
| `MEDIAPOD_AUTH_TOKEN` | API authentication token | Optional |

## Production Deployment

### Mobile Apps (iOS/Android)

For production mobile apps:
1. Use a secure configuration service to fetch credentials at runtime
2. Store credentials in platform-specific secure storage (Keychain/Keystore)
3. Consider using a backend proxy to avoid exposing imgproxy keys to clients

### Web Apps

For web deployments:
1. **Never expose imgproxy signing keys to the browser**
2. Use a backend service to generate signed URLs
3. Implement proper CORS policies on your API

### Recommended Architecture

```
[Mobile/Web Client] --> [Your Backend API] --> [Mediapod API]
                                           --> [ImgProxy]
```

Your backend should:
- Authenticate users
- Generate signed imgproxy URLs server-side
- Proxy upload requests if needed

## Reporting Security Issues

If you discover a security vulnerability, please report it responsibly:
1. **Do not** create a public GitHub issue
2. Email security concerns to the repository maintainers
3. Allow time for a fix before public disclosure

## Security Checklist

Before publishing your app:

- [ ] No hardcoded credentials in source code
- [ ] Environment variables used for all configuration
- [ ] Production URLs not committed to repository
- [ ] Debug logging disabled or sanitized in production
- [ ] HTTPS used for all API communication
- [ ] Authentication tokens stored securely
- [ ] Signed URLs expire appropriately
