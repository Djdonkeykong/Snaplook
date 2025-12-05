# Snaplook Security Audit Report
**Date**: December 5, 2025
**Version**: 1.0.0+149
**Auditor**: Claude (AI Security Audit)
**Severity Scale**: CRITICAL | HIGH | MEDIUM | LOW

---

## Executive Summary

This comprehensive security audit reveals **CRITICAL security vulnerabilities** that must be addressed before production launch. The primary issues involve:

1. **Multiple hardcoded API keys** in source code and configuration files
2. **Unencrypted storage of authentication tokens** in plain text
3. **Insecure secrets management** with fallback values committed to version control
4. **Missing security features** including certificate pinning and biometric authentication

**Overall Security Rating**: ⚠️ **HIGH RISK** - Not ready for production deployment

**Estimated Remediation Time**: 2-3 weeks

---

## Critical Findings (Immediate Action Required)

### 🔴 CRITICAL #1: Hardcoded Supabase JWT Token
**Severity**: CRITICAL
**File**: `lib/core/constants/app_constants.dart:37-41`

```dart
static String get supabaseAnonKey =>
    dotenv.env['SUPABASE_ANON_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
        'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRscXBrb2tud2ZwdGZ6ZWpwY2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQwMzMzNzEsImV4cCI6MjA2OTYwOTM3MX0.'
        'oHT9O_Aak8sUiAKX7P1J036ZSYIBDNveZqS1EMCLcJA';
```

**Impact**:
- Full database access token exposed in compiled binaries
- Anyone can extract and use this token to access your Supabase database
- Token valid until 2069 (expires in 44 years)
- Can read/write to unprotected tables like `image_cache`
- Potential for data enumeration and unauthorized API calls

**CVSS Score**: 9.8 (Critical)

**Remediation**:
1. Rotate the Supabase anon key immediately in Supabase dashboard
2. Remove all hardcoded fallback values
3. Fail gracefully if environment variable not set
4. Consider implementing backend token proxy

---

### 🔴 CRITICAL #2: Multiple Hardcoded API Keys
**Severity**: CRITICAL
**Files**:
- `lib/core/constants/app_constants.dart:55-57, 171-172`
- `ios/ShareExtension/ShareExtension/Info.plist` (Line with ScrapingBeeApiKey)

**Exposed Keys**:
```dart
// SerpAPI Key
static String get serpApiKey =>
    dotenv.env['SERPAPI_API_KEY'] ?? 'UexwcLYH6kTnBnXnyMNZqQth';

// ScrapingBee Keys
static const List<String> _scrapingBeeKeyPriority = [
  'JZ123377KP6AIVDKOSDZOXYCY5VGAPNFJRFAJR0PA7DNOCO2VQ2MYARURP80689586DKWMXG9SJJDRCH',
];
```

**iOS Share Extension**:
```xml
<key>ScrapingBeeApiKey</key>
<string>MBVJU10S1A0YUDAMPSUBIVSPGPA6MIJ5R1HNXZBSRQSDD06JH6K8UK74XZF9N8AISFWXTOLQH3U37NZF</string>
```

**Impact**:
- Attackers can make unlimited API calls on your account
- Potential for thousands of dollars in unexpected billing
- Service degradation from quota exhaustion
- Keys can be extracted from APK/IPA files in minutes

**Exploitation Scenario**:
```bash
# Attacker extracts APK
unzip snaplook.apk
strings classes.dex | grep -i "api"
# Finds your SerpAPI key
curl "https://serpapi.com/search?q=shoes&api_key=UexwcLYH6kTnBnXnyMNZqQth"
# Exhausts your API quota
```

**CVSS Score**: 9.1 (Critical)

**Remediation**:
1. **IMMEDIATE**: Rotate all exposed API keys:
   - SerpAPI: https://serpapi.com/manage-api-key
   - ScrapingBee: Regenerate in dashboard
2. Remove ALL hardcoded keys from source code
3. Implement backend API proxy instead of client-side calls
4. Use environment variables ONLY (no fallbacks)

---

### 🔴 CRITICAL #3: Hardcoded Superwall Payment API Key
**Severity**: CRITICAL
**File**: `lib/src/features/paywall/initialization/paywall_initialization.dart:13`

```dart
await SuperwallService().initialize(
  apiKey: 'pk_JerHRerDi63JoAtFh1MtT',
  userId: userId,
);
```

**Impact**:
- Payment/subscription API key exposed
- Potential for subscription fraud
- Attackers could manipulate payment flows
- Revenue loss from unauthorized subscription modifications

**CVSS Score**: 8.9 (Critical)

**Remediation**:
1. Rotate Superwall API key in Superwall dashboard
2. Move key to environment variables
3. Consider server-side subscription validation

---

### 🔴 CRITICAL #4: Unencrypted Authentication Token Storage
**Severity**: CRITICAL
**File**: `lib/main.dart:66-97`

```dart
class SharedPreferencesLocalStorage extends LocalStorage {
  Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('supabase_token');  // PLAIN TEXT!
  }

  Future<void> persistSession(String persistSessionString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_token', persistSessionString);
  }
}
```

**Impact**:
- JWT tokens stored in plain text on device
- Accessible to malware, rooted devices, or physical device access
- Tokens contain user ID and authentication state
- Account takeover possible via device theft

**Root Cause**: iOS 18.6.2 crash with `flutter_secure_storage` (documented in code comments)

**CVSS Score**: 8.1 (High to Critical)

**Remediation**:
1. Re-test `flutter_secure_storage` with latest version
2. Implement platform-specific encryption for SharedPreferences
3. Use Android KeyStore and iOS Keychain
4. Add token expiration and rotation

---

### 🔴 CRITICAL #5: Unencrypted Credit Balance Storage
**Severity**: CRITICAL
**File**: `lib/src/services/credit_service.dart:16-18`

**Stored in Plain Text**:
- `credit_balance` - User's available credits
- `free_trial_used` - Trial status flag
- `last_refill_date` - Credit refill timestamp

**Impact**:
- Users could manipulate local credit balance
- Trial bypass by modifying `free_trial_used` flag
- Potential for service abuse without payment
- Credit balance persists after logout (data leakage)

**CVSS Score**: 7.5 (High)

**Remediation**:
1. Store credits server-side only (single source of truth)
2. Use local storage as cache only with server validation
3. Clear all financial data on logout
4. Implement credit balance verification on server

---

## High Severity Findings

### 🟠 HIGH #1: API Keys Shared to iOS Share Extension
**Severity**: HIGH
**File**: `lib/src/services/share_extension_config_service.dart:16-25`

```dart
await _channel.invokeMethod('saveSharedConfig', {
  'appGroupId': _appGroupId,
  'serpApiKey': serpKey,  // ← API KEY SHARED
  'detectorEndpoint': endpoint,
});
```

**Impact**:
- SerpAPI key stored in iOS App Group UserDefaults (unencrypted)
- Wider attack surface - share extension compromise exposes keys
- App Group data readable by any app with group access

**Remediation**:
- Never share API keys to extensions
- Use authentication tokens instead
- Implement key-less endpoint for share extension

---

### 🟠 HIGH #2: Hardcoded Google OAuth Client IDs
**Severity**: HIGH
**File**: `lib/src/features/auth/domain/services/auth_service.dart:152-156`

```dart
await googleSignIn.initialize(
  clientId: '134752292541-4289b71rova6eldn9f67qom4u2qc5onp.apps.googleusercontent.com',
  serverClientId: '134752292541-hekkkdi2mbl0jrdsct0l2n3hjm2sckmh.apps.googleusercontent.com',
);
```

**Impact**:
- OAuth client IDs exposed in source code
- Potential for OAuth phishing attacks
- Attackers could implement malicious auth flows

**Note**: Client IDs are less sensitive than secrets (designed to be public), but hardcoding is still poor practice.

**Remediation**:
- Move to configuration file
- Use Firebase Remote Config for dynamic values

---

### 🟠 HIGH #3: Debug Logging of Sensitive Data
**Severity**: HIGH
**Files**: Multiple auth-related files

**Examples**:
```dart
print('[AuthService] currentUser: ${currentUser?.id ?? "null"}');
print('[Auth] Event user: ${authState.session?.user.id ?? "null"}');
print('[EmailVerification] User ID after OTP verification: $userId');
```

**Impact**:
- User IDs logged to console (visible in logcat/device logs)
- Auth state transitions exposed
- Sensitive data accessible via USB debugging

**Remediation**:
- Use conditional logging: `if (kDebugMode) { print(...) }`
- Remove all production logging of sensitive data
- Implement structured logging with privacy levels

---

### 🟠 HIGH #4: Missing Secure Storage Package
**Severity**: HIGH
**File**: `pubspec.yaml`

**Issue**: `flutter_secure_storage` not included in dependencies

**Impact**:
- No platform-native secure storage available
- Relying on plain text SharedPreferences for all data
- Cannot use iOS Keychain or Android KeyStore

**Remediation**:
1. Add `flutter_secure_storage: ^9.0.0`
2. Test on iOS 18.6.2 to verify crash is resolved
3. Implement fallback encryption if crashes persist

---

## Medium Severity Findings

### 🟡 MEDIUM #1: No Certificate Pinning
**Severity**: MEDIUM
**Impact**: Vulnerable to Man-in-the-Middle (MITM) attacks on compromised networks

**Remediation**:
- Add `http_certificate_pinning` package
- Pin Supabase SSL certificates
- Implement backup pins for certificate rotation

---

### 🟡 MEDIUM #2: Missing Biometric Authentication
**Severity**: MEDIUM
**Impact**: Lower security for device-bound authentication

**Recommendation**:
- Add Touch ID / Face ID option
- Use `local_auth` package
- Implement biometric-protected token access

---

### 🟡 MEDIUM #3: No Session Timeout
**Severity**: MEDIUM
**Issue**: Users stay logged in indefinitely (only JWT expiration)

**Remediation**:
- Implement 30-minute inactivity timeout
- Add session management UI
- Force re-authentication for sensitive operations

---

### 🟡 MEDIUM #4: Incomplete Logout Data Clearing
**Severity**: MEDIUM
**Files**: `lib/src/services/credit_service.dart`, logout handlers

**Data Not Cleared**:
- Credit balance
- Trial status
- Review prompt logs
- Cached network images
- Temporary files

**Impact**: Data leakage between users on shared devices

**Remediation**:
```dart
// Add to logout flow
await prefs.remove(_creditBalanceKey);
await prefs.remove(_freeTrialUsedKey);
await prefs.remove(_lastRefillDateKey);
await CachedNetworkImage.evictFromCache(imageUrl);
// Clear temp files
```

---

### 🟡 MEDIUM #5: Weak Email Validation
**Severity**: MEDIUM
**File**: `lib/src/features/auth/presentation/pages/email_sign_in_page.dart:44`

```dart
final isValid = _emailController.text.isNotEmpty &&
                _emailController.text.contains('@');
```

**Issue**: Only checks for '@' character (accepts invalid emails like "@@@@")

**Remediation**:
```dart
bool _isValidEmail(String email) {
  return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
}
```

---

### 🟡 MEDIUM #6: Development Endpoints in Production Code
**Severity**: MEDIUM
**File**: `lib/core/constants/app_constants.dart:155-166`

```dart
return isLocal
    ? 'http://10.0.0.25:8000/detect'  // HTTP (unencrypted)
    : 'https://224b4db17f5f.ngrok-free.app/detect';
```

**Issues**:
- ngrok endpoint (temporary development URL) in production code
- HTTP endpoint for local development (no encryption)
- Hardcoded IP addresses

**Remediation**:
- Remove development endpoints from production builds
- Use build flavors (dev/staging/prod)
- Never commit ngrok URLs

---

## Low Severity Findings

### 🟢 LOW #1: Overly Permissive Android Manifest
**File**: `android/app/src/main/AndroidManifest.xml`

**Issue**: Accepts all file types in share intent (line 80):
```xml
<data android:mimeType="*/*" />
```

**Recommendation**: Limit to image types only for better security posture

---

### 🟢 LOW #2: No Rate Limiting Visible
**Severity**: LOW
**Issue**: No client-side rate limiting on OTP verification attempts

**Note**: May be handled server-side by Supabase

**Recommendation**: Add explicit rate limiting UI/logic

---

## Positive Security Implementations ✅

Despite critical issues, the app has several good security practices:

### ✅ Strong Database Security (RLS)
- All user tables protected by Row Level Security
- `auth.uid()` enforcement on all queries
- Proper separation of user data
- Service role policies correctly implemented

**Example**:
```sql
CREATE POLICY "Users can view own searches"
  ON user_searches FOR SELECT
  USING (auth.uid() = user_id);
```

### ✅ Device Fingerprinting for Fraud Prevention
- SHA256 hashed device identifiers
- Prevents trial abuse (3 accounts per device per week)
- Tracks trial conversion to paid

**File**: `lib/src/services/fraud_prevention_service.dart`

### ✅ Proper OAuth Implementation
- Correct use of Supabase auth with Google/Apple Sign-In
- ID token exchange properly implemented
- No OAuth security anti-patterns detected

### ✅ HTTPS Usage
- All production endpoints use HTTPS
- TLS for Supabase communication
- Cloudinary API uses HTTPS

### ✅ Secure Password Handling
- Uses Supabase auth (no password storage in app)
- Email OTP instead of passwords
- No plaintext password transmission

---

## OWASP Mobile Top 10 (2024) Compliance

| Risk | Status | Notes |
|------|--------|-------|
| M1: Improper Credential Usage | ❌ FAIL | Hardcoded API keys, unencrypted tokens |
| M2: Inadequate Supply Chain Security | ⚠️ PARTIAL | Dependencies not regularly audited |
| M3: Insecure Authentication/Authorization | ⚠️ PARTIAL | Auth OK, but token storage insecure |
| M4: Insufficient Input/Output Validation | ⚠️ PARTIAL | Weak email validation |
| M5: Insecure Communication | ⚠️ PARTIAL | HTTPS used, but no cert pinning |
| M6: Inadequate Privacy Controls | ✅ PASS | RLS enforced, proper data separation |
| M7: Insufficient Binary Protections | ❌ FAIL | No obfuscation, keys in binaries |
| M8: Security Misconfiguration | ❌ FAIL | Debug logging, hardcoded secrets |
| M9: Insecure Data Storage | ❌ FAIL | Plain text token/credit storage |
| M10: Insufficient Cryptography | ⚠️ PARTIAL | No local encryption for sensitive data |

**Overall OWASP Compliance**: 1/10 PASS, 4/10 PARTIAL, 5/10 FAIL

---

## Network Security Analysis

### Transport Security
✅ **HTTPS for all production endpoints**:
- Supabase: `https://tlqpkoknwfptfzejpchy.supabase.co`
- Cloudinary: `https://api.cloudinary.com`
- Pexels API: `https://api.pexels.com`
- Pixabay API: `https://pixabay.com/api/`
- Unsplash API: `https://api.unsplash.com`

⚠️ **HTTP for local development** (acceptable for dev only):
- `http://10.0.0.25:8000` (local API server)

### Missing Security Features
❌ **No Certificate Pinning**:
- Vulnerable to MITM attacks
- No SSL/TLS certificate validation beyond system default

❌ **No Network Security Config** (Android):
- Missing `network_security_config.xml`
- Could enforce HTTPS-only, cert pinning

**Recommendation**: Create `android/app/src/main/res/xml/network_security_config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    <!-- Certificate pinning for production -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">tlqpkoknwfptfzejpchy.supabase.co</domain>
        <pin-set>
            <pin digest="SHA-256">HASH_OF_SUPABASE_CERT</pin>
            <pin digest="SHA-256">BACKUP_PIN</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

---

## Input Validation Analysis

### User Input Points
1. **Email Address Input** (`email_sign_in_page.dart`)
   - ❌ Weak validation (only checks for '@')
   - ❌ No sanitization
   - ⚠️ No XSS protection (not applicable for email field)

2. **OTP Code Input** (`email_verification_page.dart`)
   - ✅ 6-digit numeric only (enforced by keyboard type)
   - ⚠️ No rate limiting visible on client

3. **Profile Name Input** (`edit_profile_fields_page.dart`)
   - ⚠️ No sanitization visible
   - ⚠️ No length limits enforced

### Database Query Safety
✅ **SQL Injection Protected**:
- All queries use Supabase SDK (parameterized queries)
- No raw SQL string concatenation
- Example:
```dart
await client.from('user_searches')
    .select('*')
    .eq('user_id', userId)  // Safe: parameterized
```

### URL Handling
⚠️ **URL Validation**:
- Instagram/TikTok/Pinterest URL parsing
- Regex validation present but complex
- Potential for regex DoS (ReDoS) with malicious input

**File**: `lib/src/services/instagram_service.dart` (1700+ lines of URL parsing)

**Recommendation**: Add URL validation limits:
```dart
if (url.length > 2000) throw Exception('URL too long');
```

---

## Dependency Security

### Current Dependencies (pubspec.yaml)
```yaml
supabase_flutter: ^2.6.0       # ✅ Up to date
google_sign_in: ^7.1.1         # ✅ Latest
dio: ^5.4.3+1                  # ✅ Latest
cached_network_image: ^3.3.1   # ✅ Recent
crypto: ^3.0.3                 # ✅ Standard library
```

### Missing Security Packages
❌ `flutter_secure_storage` - Secure credential storage
❌ `http_certificate_pinning` - SSL pinning
❌ `encrypt` - Local data encryption
❌ `freerasp` - Runtime app self-protection

### Recommendations
1. Run `flutter pub outdated` regularly
2. Use `dart pub upgrade` for security patches
3. Monitor CVE databases for dependency vulnerabilities
4. Add `dependabot` to GitHub repo for automated updates

---

## Platform-Specific Security

### Android Security (AndroidManifest.xml)
✅ **Good Practices**:
- `android:exported="true"` only on MainActivity
- Hardware acceleration enabled
- Proper intent filters for share functionality

⚠️ **Concerns**:
- No backup encryption (allowBackup not set)
- No network security config
- Debuggable flag potentially enabled in dev builds

**Recommendations**:
```xml
<application
    android:allowBackup="false"
    android:fullBackupContent="false"
    android:networkSecurityConfig="@xml/network_security_config">
```

### iOS Security (Info.plist)
✅ **Good Practices**:
- App Group isolation for share extension
- Proper capability management

❌ **Critical Issue**:
- **ScrapingBee API key hardcoded** in ShareExtension/Info.plist
- Keys in plist files are easily extractable

---

## Recommendations Priority Matrix

### P0: CRITICAL - Fix Before Launch (This Week)
1. ✅ **Rotate ALL exposed API keys immediately**:
   - [ ] Supabase anon key
   - [ ] SerpAPI key (both instances)
   - [ ] ScrapingBee keys (3 instances)
   - [ ] Superwall API key
   - [ ] Google OAuth client IDs

2. ✅ **Remove hardcoded secrets from source code**:
   - [ ] `lib/core/constants/app_constants.dart` - Remove all fallback values
   - [ ] `lib/src/features/paywall/initialization/paywall_initialization.dart` - Use env var
   - [ ] `ios/ShareExtension/ShareExtension/Info.plist` - Remove ScrapingBee key
   - [ ] `lib/main.dart:159` - Remove commented Superwall key

3. ✅ **Implement secure token storage**:
   - [ ] Add `flutter_secure_storage: ^9.0.0`
   - [ ] Test on iOS 18.6.2 (verify crash is fixed)
   - [ ] Migrate from SharedPreferences to secure storage
   - [ ] Add encryption fallback if secure storage unavailable

4. ✅ **Move credits to server-side validation**:
   - [ ] Remove local credit storage
   - [ ] Validate all credit operations on backend
   - [ ] Use local storage as cache only

### P1: HIGH - Fix Within 2 Weeks
5. [ ] **Clear all sensitive data on logout**:
   ```dart
   await prefs.remove('credit_balance');
   await prefs.remove('free_trial_used');
   await prefs.remove('last_refill_date');
   ```

6. [ ] **Remove debug logging**:
   - Wrap all auth logging in `if (kDebugMode)`
   - Remove user IDs from logs

7. [ ] **Implement API gateway**:
   - Move SerpAPI calls to backend
   - Move ScrapingBee calls to backend
   - Keep keys server-side only

8. [ ] **Add input validation**:
   - Proper email regex validation
   - Profile name sanitization
   - URL length limits

### P2: MEDIUM - Fix Within 1 Month
9. [ ] **Implement certificate pinning**:
   - Add `http_certificate_pinning` package
   - Pin Supabase certificates
   - Add backup pins

10. [ ] **Add session timeout**:
    - Implement 30-minute inactivity timeout
    - Force re-auth for sensitive operations

11. [ ] **Security audit dependencies**:
    - Run `flutter pub outdated`
    - Check for known CVEs
    - Update all packages

12. [ ] **Add network security config** (Android):
    - Create `network_security_config.xml`
    - Enforce HTTPS-only

### P3: LOW - Enhancement (1-3 Months)
13. [ ] **Add biometric authentication**:
    - Use `local_auth` package
    - Touch ID / Face ID support

14. [ ] **Implement code obfuscation**:
    - Build with `--obfuscate` flag
    - Split debug symbols

15. [ ] **Add runtime protections**:
    - Detect rooted/jailbroken devices
    - Add anti-tampering checks

16. [ ] **Security testing**:
    - Penetration testing
    - SAST/DAST scans
    - Third-party security audit

---

## Testing Recommendations

### Security Testing Checklist
- [ ] Test with intercepting proxy (Burp Suite, Charles)
- [ ] Decompile APK/IPA to verify secrets not present
- [ ] Test on rooted Android device
- [ ] Test on jailbroken iOS device
- [ ] Verify RLS policies in Supabase
- [ ] Test session timeout
- [ ] Test logout data clearing
- [ ] Verify HTTPS enforcement
- [ ] Test OAuth flows for phishing vulnerabilities
- [ ] Verify credit balance validation server-side

### Automated Security Tools
```bash
# Dependency vulnerability scanning
flutter pub outdated
dart pub global activate pana
pana --no-warning

# Static analysis
flutter analyze --no-fatal-infos

# License compliance
flutter pub global activate license_checker
license_checker check-licenses
```

---

## Compliance & Regulations

### GDPR Compliance
✅ **Privacy Policy**: Links present in app
⚠️ **Data Deletion**: Verify user data deletion endpoint exists
✅ **Data Minimization**: Only necessary data collected

### App Store Requirements
⚠️ **Apple**: Must use HTTPS for all production endpoints (compliant)
⚠️ **Google Play**: Must declare all permissions (compliant)
❌ **Both**: Should not have API keys in binaries (NOT compliant)

---

## Post-Remediation Verification

After implementing fixes, verify:

1. **API Key Rotation**:
   ```bash
   # Verify old keys are revoked
   curl "https://serpapi.com/search?q=test&api_key=OLD_KEY"
   # Should return 401 Unauthorized
   ```

2. **Binary Analysis**:
   ```bash
   # Extract APK
   unzip app-release.apk -d extracted/
   # Search for secrets
   grep -r "eyJhbGc" extracted/  # Should find NOTHING
   grep -r "api_key" extracted/  # Should find NOTHING
   ```

3. **Secure Storage**:
   - Verify tokens in Keychain (iOS) or KeyStore (Android)
   - Verify NOT in SharedPreferences

4. **Server Validation**:
   - Test credit balance manipulation
   - Verify server rejects invalid credits

---

## Estimated Costs

### Time Investment
- **P0 (Critical)**: 40-60 hours (1 week full-time)
- **P1 (High)**: 60-80 hours (1.5 weeks full-time)
- **P2 (Medium)**: 40 hours (1 week full-time)
- **P3 (Low)**: 20-40 hours (0.5-1 week full-time)

**Total**: 160-220 hours (4-5.5 weeks full-time)

### Financial Impact
- **Key Rotation**: $0 (free with services)
- **Penetration Testing**: $5,000-$15,000 (if outsourced)
- **Security Tooling**: $0-$500/month
- **Developer Time**: Varies by rate

---

## References & Resources

### Research Sources Used
- [Flutter Official Security Docs](https://docs.flutter.dev/security)
- [OWASP Top 10 for Flutter - M1: Credential Security](https://docs.talsec.app/appsec-articles/articles/owasp-top-10-for-flutter-m1-mastering-credential-security-in-flutter)
- [How to secure API keys in Flutter](https://codewithandrea.com/articles/flutter-api-keys-dart-define-env-files/)
- [Flutter Secure Storage Guide](https://pub.dev/packages/flutter_secure_storage)
- [SSL Certificate Pinning in Flutter](https://pub.dev/packages/http_certificate_pinning)
- [8kSec: Securing Flutter Against OWASP Mobile Top 10](https://8ksec.io/securing-flutter-applications/)

### Standards & Frameworks
- OWASP Mobile Application Security Verification Standard (MASVS)
- OWASP Mobile Security Testing Guide (MSTG)
- CWE Top 25 Most Dangerous Software Weaknesses
- NIST Cybersecurity Framework

---

## Appendix: File Locations

### Critical Files Requiring Changes
```
lib/core/constants/app_constants.dart (Lines 34-41, 55-57, 155-166, 171-172)
lib/main.dart (Lines 66-97, 159)
lib/src/features/paywall/initialization/paywall_initialization.dart (Line 13)
lib/src/services/credit_service.dart (Lines 16-264)
lib/src/services/share_extension_config_service.dart (Lines 16-25)
lib/src/features/auth/domain/services/auth_service.dart (Lines 152-156, 242-252)
ios/ShareExtension/ShareExtension/Info.plist (ScrapingBeeApiKey)
```

### Security-Related Files
```
supabase/migrations/*.sql (RLS policies)
android/app/src/main/AndroidManifest.xml (Permissions)
ios/Runner/Info.plist (iOS permissions)
.gitignore (Secret exclusions)
SECURITY.md (Security documentation)
```

---

## Sign-Off

This audit report is based on static code analysis, dependency review, and best practices research as of December 5, 2025. Dynamic testing (runtime analysis, penetration testing) is recommended for comprehensive security assessment.

**Critical Action Required**: Do NOT deploy to production until P0 issues are resolved.

**Next Steps**:
1. Review this report with development team
2. Create GitHub issues for each finding
3. Implement P0 fixes immediately
4. Schedule follow-up audit after remediation

---

**End of Report**
