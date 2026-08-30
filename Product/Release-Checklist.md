# TestFlight checklist 1.0.0 (build 1)

## Im Projekt erledigt

- [x] iPhone-only target with iOS 18 minimum and Release configuration.
- [x] App and widget bundle identifiers, App Group and iCloud container configured.
- [x] App icon, privacy manifest, camera/photo descriptions and export-compliance flag included.
- [x] German and English app name, interface and permission descriptions included.
- [x] Privacy Policy, Support and Terms of Use linked inside the app and in the metadata.
- [x] StoreKit product identifiers and German/English App Store metadata documented.

## Einmalig in Apple/Xcode erledigen

- [ ] Select the Kamilunavo Apple Developer Team for app, widget and tests under Signing & Capabilities.
- [ ] Confirm that the App ID, `iCloud.com.kamilunavo.schon-erledigt` and `group.com.kamilunavo.schon-erledigt` exist in the developer account.
- [ ] Create the annual and lifetime StoreKit products with the exact identifiers from `Review-Notes.md`.
- [ ] Publish the included privacy and support pages at the URLs from the App Store metadata.
- [ ] Run tests, then test camera denial, notification denial, the widget after app termination and an iCloud invitation using two Apple IDs.
- [ ] Deploy the CloudKit development schema to Production in CloudKit Console.
- [ ] Select **Any iOS Device (arm64)**, then use **Product > Archive**.
- [ ] In Organizer choose **Distribute App > App Store Connect > Upload**, keeping automatic signing enabled.
- [ ] In App Store Connect complete App Privacy, attach both purchases and add 6.9-inch screenshots in German and English.
