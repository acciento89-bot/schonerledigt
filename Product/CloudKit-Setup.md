# CloudKit production setup

1. Register App ID `com.kamilunavo.schon-erledigt` and widget App ID `com.kamilunavo.schon-erledigt.widget`.
2. Enable iCloud/CloudKit and create `iCloud.com.kamilunavo.schon-erledigt`.
3. Create App Group `group.com.kamilunavo.schon-erledigt` and assign both targets.
4. Run once on a signed device, then confirm `Household` with `name` (String) and `snapshot` (Asset) in CloudKit Console.
5. Test owner and participant accounts through TestFlight.
6. Deploy the schema to Production before App Review.
