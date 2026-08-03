# iOS Unsigned Build & Configuration Guide (For AI Agents)

**ATTENTION AI AGENT**: If you are tasked with building a Flutter iOS app without an Apple Developer Account (e.g., for jailbroken devices or unsigned `.ipa` distribution via CI/CD), you **MUST** follow these strict guidelines. Failure to do so will result in `xcodebuild` failures, immediate app crashes (`Killed: 9`), or silent Flutter exceptions.

## 1. Bypassing Xcode Code Signing in CI/CD
Standard `flutter build ios` will inherently fail if certificates are missing. You must bypass Flutter's internal Xcode validator and force raw `xcodebuild` arguments.

**Do NOT attempt to inject a dummy `DEVELOPMENT_TEAM` into `project.pbxproj`. It is flaky and often fails on newer Xcode versions.**

Instead, use this exact GitHub Actions bash sequence:
```yaml
      - name: Build iOS without Code Signing
        run: |
          # 1. Generate Podfile (ignore code sign errors)
          flutter build ios --release --no-codesign || true
          
          # 2. Inject Code Signing overrides into Podfile
          cat << 'EOF' > patch_podfile.rb
          require 'fileutils'
          content = File.read('ios/Podfile')
          new_content = content.gsub(/flutter_additional_ios_build_settings\(target\)/, "flutter_additional_ios_build_settings(target)\n      target.build_configurations.each do |config|\n        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'\n        config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'\n        config.build_settings['CODE_SIGN_IDENTITY'] = '-'\n        config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = '-'\n      end")
          File.write('ios/Podfile', new_content)
          EOF
          ruby patch_podfile.rb
          
          # 3. Install Pods
          cd ios
          pod install
          cd ..
          
          # 4. Generate AOT (ignore code sign errors)
          flutter build ios --release --no-codesign || true
          
          # 5. Native Xcode Build (Force signing disabled)
          cd ios
          xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
          cd ..
```

## 2. Preventing Instant Crashes (`Killed: 9`)
A purely unsigned binary will be killed instantly by the iOS kernel on launch, even on a jailbroken device, because it lacks entitlements.
You **must** pseudo-sign the executable using `ldid` before zipping the `.ipa`.

```yaml
      - name: Install ldid
        run: brew install ldid

      - name: Package and Pseudo-sign into IPA
        run: |
          APP_PATH=$(find build ios -name "Runner.app" -type d | head -n 1)
          mkdir -p Payload
          mv "$APP_PATH" Payload/
          
          # CRITICAL: Pseudo-sign the binary so it doesn't get Killed: 9
          ldid -S Payload/Runner.app/Runner
          
          zip -r AppName.ipa Payload
```

## 3. iOS File System Constraints
**Never hardcode Android paths.** Attempting to write to `/storage/emulated/0/...` on iOS will trigger a fatal `err no=1` (Operation not permitted).
- Always use `path_provider` to fetch `getApplicationDocumentsDirectory()`.
- If the user needs to see the exported files manually, you **MUST** add the following to `ios/Runner/Info.plist`:
```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

## 4. Google Sign-In & Auth Crashes
The `google_sign_in` package on iOS will instantly crash the app on startup if the URL scheme is missing.
- You **MUST** specify the `clientId` in the dart initialization if `GoogleService-Info.plist` is absent.
- You **MUST** inject the reversed client ID into `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

## 5. Google Mobile Ads SDK Crashes
If you add `google_mobile_ads`, the app will instantly crash on launch if the App ID is missing.
- You **MUST** add `GADApplicationIdentifier` to `ios/Runner/Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string> 
<!-- Use Google's test ID during dev, swap for production later -->
```

## 6. Advanced Features (Firebase, WebRTC, Audio, Push)
When building more complex apps (like Music or WebRTC-based communication apps), iOS enforces strict sandboxing rules that differ significantly from Android:

### Firebase Integration
If the app uses Firebase, initializing it without the configuration file will cause a native crash.
- You **MUST** ensure `GoogleService-Info.plist` is bundled in the Xcode project via `project.pbxproj`. If it is missing, `Firebase.initializeApp()` will crash the app instantly.

### Background Audio (Music Apps)
Unlike Android, iOS will suspend/kill your app the exact second it goes to the background. 
- To play audio or music in the background, you **MUST** configure the `UIBackgroundModes` capability in `Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

### WebRTC / Blackboard / Calling
WebRTC and calling features require strict permissions. The app will crash if these are missing when requested:
- `NSMicrophoneUsageDescription`: Required for any audio capture/calls.
- `NSCameraUsageDescription`: Required for video calls.
- `NSLocalNetworkUsageDescription`: WebRTC often discovers local network peers. iOS 14+ requires this permission or it will silently block local network traffic.
- **Background Calling**: VoIP calls require the `voip` flag in `UIBackgroundModes`. 

### Push Notifications Constraints
Apple Push Notification Service (APNs) requires a cryptographic handshake between the app's valid provisioning profile and Apple's servers. 
- **Purely unsigned/pseudo-signed apps cannot receive native APNs push notifications.** 
- If you rely on push notifications (e.g., Firebase Cloud Messaging), they will silently fail on an unsigned app. As a workaround for unsigned apps, you must use persistent WebSockets or long-polling while the app is in the foreground, or use local notifications (`flutter_local_notifications`).
