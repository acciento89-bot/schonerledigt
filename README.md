# Schon erledigt? — iOS 1.0.0

Native, iPhone-only SwiftUI app for recurring everyday confirmations. No Android project and no third-party dependencies.

## Included

- recurring cards with one-tap confirmation, timestamps and automatic reset
- create, edit, delete and reopen cards
- free limit of six cards and 30 days of history
- StoreKit 2 annual and lifetime Pro unlocks
- optional compressed photo proof and local reset notifications
- private CloudKit household sync and Apple share invitations
- interactive small and medium Home Screen widgets
- German and English interface, Dynamic Type and accessibility labels
- app-group JSON persistence and unit tests for reset rules

## Open in Xcode

```bash
git clone https://github.com/acciento89-bot/schonerledigt.git
cd schonerledigt
open SchonErledigt.xcodeproj
```

1. Open the project in Xcode 16 or newer.
2. Select the Apple Developer Team for app, widget and tests.
3. Follow `Product/Release-Checklist.md` for account-dependent release steps.

The source requires iOS 18 or newer and targets iPhone only (`TARGETED_DEVICE_FAMILY = 1`). It uses no external servers, tracking, ads or third-party SDKs.

The app documents user input; it cannot verify a real-world safety or medical condition.
