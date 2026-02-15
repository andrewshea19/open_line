### CloudKit setup (container, schema, and iCloud enablement)

This app uses a public CloudKit container to sync profiles, friend requests, and friend availability. Follow these steps to enable iCloud and set up the schema.

---

#### 1) Prerequisites
- Apple Developer Program membership
- Bundle ID: `com.shea.OpenLine`
- CloudKit container: `iCloud.com.shea.OpenLine`

#### 2) Enable iCloud + CloudKit for the app
1. In Apple Developer portal, enable iCloud capability for `com.shea.OpenLine` and add the container `iCloud.com.shea.OpenLine`.
2. In Xcode (Signing & Capabilities): iCloud → CloudKit enabled. The entitlements in `OpenLine/OpenLine.entitlements` already include the container.
3. On the simulator/device, sign into an iCloud account (Settings → iCloud) before running the app.

#### 3) Create/verify the container in CloudKit Dashboard
1. Open the CloudKit Dashboard: https://icloud.developer.apple.com/dashboard
2. Sign in with your Apple Developer account
3. Select the container `iCloud.com.shea.OpenLine` from the container list
4. Ensure you're in the **Development** environment (toggle in top-right if needed)
5. Verify "Allow schema changes in Development" is enabled (should be enabled by default)

**Important**: CloudKit requires fields used in queries to be explicitly marked as "Queryable" in the Dashboard. Auto-created schemas don't automatically mark fields as queryable, so you must do this manually after the first record save (see step 7).

---

#### 4) Record types and fields

**CRITICAL: All fields used in queries MUST be marked as "Queryable" in CloudKit Dashboard**

- Record type: `UserProfile`
  - `cloudKitUserID` (String) — stable iCloud user record ID — **MUST be Queryable**
  - `name` (String)
  - `phoneNumber` (String) — **MUST be Queryable**
  - `email` (String, optional) — **MUST be Queryable** (if searching by email)
  - `currentStatus` (String) — e.g., "Available", "Commuting", etc.
  - `statusMessage` (String)
  - `statusUntil` (Date, optional)
  - `lastStatusUpdate` (Date, optional)
  - `isDiscoverable` (Number 0/1) — **MUST be Queryable** (used in search filters)
  - `deviceTokens` (String List, optional)

  **Required Queryable indexes** (mark these in CloudKit Dashboard):
  - ✅ `cloudKitUserID` — Queryable
  - ✅ `phoneNumber` — Queryable  
  - ✅ `email` — Queryable
  - ✅ `isDiscoverable` — Queryable

- Record type: `FriendRequest`
  - `fromUserID` (String, indexed)
  - `fromUserName` (String)
  - `fromUserPhone` (String)
  - `fromUserEmail` (String, optional)
  - `toUserID` (String, indexed)
  - `toUserName` (String)
  - `toUserPhone` (String)
  - `toUserEmail` (String, optional)
  - `message` (String, optional)
  - `status` (String: "Pending" | "Accepted" | "Declined" | "Expired")
  - `createdAt` (Date)
  - `respondedAt` (Date, optional)

  **Required Queryable indexes** (mark these in CloudKit Dashboard):
  - ✅ `toUserID` — Queryable
  - ✅ `fromUserID` — Queryable

Note: CloudKit doesn’t have a native Boolean type; store booleans as Number 0/1.

---

#### 5) Security and deployment
- Environment:
  - Use Development while building and testing; schema changes occur here.
  - Once verified, Dashboard → Deploy Schema to Production.
- Access:
  - For demo/MVP, set Public DB read access to “Authenticated” in Production.
  - For privacy in a real release, prefer hashing and indexing normalized phone/email or using user-to-user references instead of querying plain phone/email.

---

#### 6) What the app expects (queries it issues)
- Find current user profile by `cloudKitUserID` (auto-fetched from iCloud) or seed from local cache if missing.
- Search user by phone/email (only where `isDiscoverable == 1`).
- Create friend request records with `status` = "Pending".
- Fetch incoming requests by `toUserID`; outgoing by `fromUserID`.
- Accept/decline request updates `status` and `respondedAt`.
- Fetch friends’ profiles by their `cloudKitUserID` list to read status fields.

These correspond to schema keys hardcoded in `CloudKitManager` so any schema drift will break queries; keep names/types consistent.

---

#### 7) Marking fields as Queryable (CRITICAL STEP - REQUIRED!)

**This step is REQUIRED** - the app will show "indexable" errors until these fields are marked as Queryable.

##### Step 7a: First, create a record to auto-generate the schema

1. **Run the app** in the simulator (or on a device) while signed into iCloud
2. **Complete onboarding** or set up your profile - this will create your first `UserProfile` record
3. The schema will be auto-created in CloudKit Dashboard, but fields won't be marked as Queryable yet

##### Step 7b: Mark UserProfile fields as Queryable

1. In **CloudKit Dashboard**, navigate to: **Schema** → **Record Types**
2. Find and click on the **`UserProfile`** record type
3. You'll see a list of all fields (cloudKitUserID, name, phoneNumber, etc.)
4. For each of these **4 fields**, click on the field name, then check the **"Queryable"** checkbox:
   - **`cloudKitUserID`**
     - Click on the field row
     - In the field details panel on the right, find the **"Queryable"** checkbox
     - ✅ **Check "Queryable"**
   - **`phoneNumber`**
     - Click on the field row
     - ✅ **Check "Queryable"**
   - **`email`**
     - Click on the field row
     - ✅ **Check "Queryable"**
   - **`isDiscoverable`**
     - Click on the field row
     - ✅ **Check "Queryable"**
5. After marking all 4 fields, click **"Save Schema"** button (usually in top-right or bottom of the Record Type view)
6. Wait for the save to complete (you may see a confirmation message)

##### Step 7c: Create and mark FriendRequest fields as Queryable

**Note**: The `FriendRequest` record type will be auto-created when you send your first friend request in the app. If you haven't sent a friend request yet, you have two options:

**Option A (Recommended): Create the schema by sending a test friend request**
1. In the app, go to "Add Friend"
2. Search for a test user or enter a phone number
3. Send a friend request (even if it fails, it will create the schema)
4. Go back to CloudKit Dashboard and continue with steps below

**Option B: Manually create the FriendRequest record type in Dashboard**
1. In **CloudKit Dashboard** → **Schema** → **Record Types**, click **"+"** or **"Add Record Type"**
2. Name it **`FriendRequest`** (exact name, case-sensitive)
3. Add all the fields listed in section 4 above (fromUserID, toUserID, etc.)
4. Set correct types: String for text fields, Date for createdAt/respondedAt, Number for status if needed

**Then mark fields as Queryable:**
1. In **Record Types** view, find and click on **`FriendRequest`**
2. Mark these 2 fields as Queryable:
   - **`toUserID`** → Click field → ✅ Check "Queryable"
   - **`fromUserID`** → Click field → ✅ Check "Queryable"
3. Click **"Save Schema"** again

##### Step 7d: Verify your changes

1. In the Record Types view, you should see a small "Queryable" icon or indicator next to the fields you marked
2. The schema status should show "Saved" or "Up to date"
3. **Restart your app** - the "indexable" errors should now be gone

**Troubleshooting:**
- **"Unknown field 'toUserID'" error**: The `FriendRequest` record type doesn't exist yet. Send a test friend request in the app to auto-create it, then come back to mark fields as Queryable.
- If you don't see "Queryable" checkboxes, make sure you're in **Development** environment (not Production)
- If fields don't appear, run the app once to create a record and generate the schema first
- If the "Save Schema" button is disabled, ensure "Allow schema changes in Development" is enabled
- If `FriendRequest` record type doesn't appear in the list, send a friend request in the app first to auto-create it

#### 8) Verification and testing

After completing step 7 (marking fields as Queryable):

1. **Restart your app** completely (force quit and relaunch)
2. The "indexable" error should no longer appear
3. **If you see "Unknown field" errors for FriendRequest:**
   - This is normal if you haven't sent a friend request yet
   - The app will handle this gracefully (no crash)
   - Send a test friend request to auto-create the FriendRequest schema
   - Then mark `toUserID` and `fromUserID` as Queryable (step 7c)
4. **In CloudKit Dashboard → Data**, verify:
   - A `UserProfile` record exists for your iCloud account
   - The record has your `cloudKitUserID`, `phoneNumber`, `name`, etc.
   - (Optional) A `FriendRequest` record exists if you've sent a request
5. **Test searching:**
   - In the app, go to "Add Friend"
   - Try searching by phone number or email
   - If another user exists with that phone/email and `isDiscoverable = 1`, they should appear
6. **Test friend requests (this will auto-create FriendRequest schema):**
   - Send a friend request to another user (or yourself for testing)
   - **After sending**, go to Dashboard → Schema → Record Types
   - You should now see `FriendRequest` record type with all fields
   - Mark `toUserID` and `fromUserID` as Queryable (if you haven't already)
   - In Dashboard → Data → `FriendRequest`, verify the record appears with `status = "Pending"`
   - Accept/decline in the app, then verify `status` and `respondedAt` update in Dashboard
7. **Test friend status sync:**
   - Friend statuses should automatically sync from CloudKit
   - Updates to friend profiles should appear in the Friends list

If you still see errors after marking fields as Queryable, verify:
- You're in **Development** environment in Dashboard
- All 6 fields are marked as Queryable (4 for UserProfile, 2 for FriendRequest)
- You clicked "Save Schema" after making changes
- You fully restarted the app (not just backgrounded)
- For "Unknown field" errors: Send a friend request first to create the FriendRequest schema

---

#### 9) Notes
- Development schema can be auto-generated by the app; always "Deploy to Production" once stable.
- If you change any field names, update `CloudKitManager` to keep keys aligned.
- For push updates, add APNs device tokens into `deviceTokens` and use CloudKit subscriptions.

---

#### 10) CloudKit Subscription Setup

The app uses CloudKit subscriptions to receive real-time notifications when:
- A user receives a new friend request
- A friend request status changes (accepted/declined)

**Subscriptions are created automatically** when the app launches and the user profile is loaded. The following subscriptions are created:

1. **`incoming-friend-requests-{userID}`**: Fires when a new FriendRequest record is created where `toUserID` matches the current user
2. **`friend-status-changes-{userID}`**: Fires when a FriendRequest record is updated where `fromUserID` matches the current user

**Requirements for subscriptions to work:**
- Push Notifications capability must be enabled in App ID (Apple Developer Portal)
- APNs environment key must be set in entitlements (`development` or `production`)
- User must grant notification permissions in the app
- Device token must be registered with Apple and saved to CloudKit

---

#### 11) Production Deployment Checklist

Before submitting to the App Store, complete these steps:

**CloudKit Dashboard:**
- [ ] Go to CloudKit Dashboard → Schema
- [ ] Click "Deploy Schema to Production" to copy Development schema to Production
- [ ] Verify all record types (UserProfile, FriendRequest) exist in Production
- [ ] Verify all Queryable indexes are present in Production

**Apple Developer Portal:**
- [ ] Ensure Push Notifications capability is enabled for App ID `com.shea.OpenLine`
- [ ] Create APNs Key or Certificate for push notifications
- [ ] Verify iCloud (CloudKit) capability is enabled

**Xcode Project:**
- [ ] Change `aps-environment` in `OpenLine.entitlements` from `development` to `production`
- [ ] Verify Bundle ID matches: `com.shea.OpenLine`
- [ ] Verify Team ID is correct in Signing & Capabilities
- [ ] Archive and upload to App Store Connect

**App Store Connect:**
- [ ] Add app screenshots (required sizes for each device)
- [ ] Write app description and keywords
- [ ] Set age rating (likely 4+ if no mature content)
- [ ] Add Privacy Policy URL (required)
- [ ] Complete App Privacy questionnaire
- [ ] Submit for review

**Testing before submission:**
- [ ] Test on physical device with Production CloudKit environment
- [ ] Verify push notifications work between two different iCloud accounts
- [ ] Test friend request flow end-to-end
- [ ] Verify data syncs correctly after app restart
- [ ] Test offline behavior and reconnection


