# Firestore Security Rules - Manual Test Scenarios

## Test Accounts Setup

Create 4 test accounts before testing:

- **UserA** - <user.a@test.com>
- **UserB** - <user.b@test.com>  
- **UserC** - <user.c@test.com>
- **UserD** - <user.d@test.com>

---

## SCENARIO 1: Group Creation & Membership

### Test 1.1: Create Group

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** | Success |
| 2 | Go to Groups → Create Group "Family" | ✅ Group created, UserA is Owner |
| 3 | Check group list | ✅ "Family" visible |

### Test 1.2: Join Group

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** | Copy "Family" group ID |
| 2 | Login as **UserB** | Paste group ID → Join |
| 3 | Check group list | ✅ "Family" visible for UserB |
| 4 | Login as **UserA** | ✅ UserB visible in Manage Members |

### Test 1.3: Non-Member Cannot See Group

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserC** (not in Family) | - |
| 2 | Check calendar/details | ❌ UserA & UserB NOT visible |

---

## SCENARIO 2: Role Permissions

### Test 2.1: Owner Promotes Admin

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** (Owner of Family) | - |
| 2 | Go to Manage Members | - |
| 3 | Click menu on UserB → Promote to Admin | ✅ UserB is now Admin |

### Test 2.2: Admin Cannot Promote Others

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserB** (Admin of Family) | - |
| 2 | **UserC** joins Family group | - |
| 3 | UserB opens Manage Members | ❌ No "Promote" option visible |

### Test 2.3: Owner Transfers Ownership

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** (Owner) | - |
| 2 | Manage Members → Transfer Ownership to UserB | ✅ UserB becomes Owner |
| 3 | Login as **UserB** | ✅ Full owner controls visible |
| 4 | Login as **UserA** | ✅ UserA is now just Admin |

---

## SCENARIO 3: User Locations

### Test 3.1: Set Own Location

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** | - |
| 2 | Open Location Picker | - |
| 3 | Select Malaysia, Penang → Today | ✅ Location saved |
| 4 | Check calendar tile | ✅ Shows Malaysia |

### Test 3.2: Group Member Sees Location

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserB** (same group as UserA) | - |
| 2 | Click today's tile → Details | ✅ UserA's location visible |

### Test 3.3: Non-Member Cannot See Location

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserD** (not in Family) | - |
| 2 | Click today's tile → Details | ❌ UserA NOT visible |

### Test 3.4: Owner/Admin Can Set Member Location

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** (Owner) | - |
| 2 | Click tile → Details → Click edit on UserB | - |
| 3 | Set UserB's location to Japan | ✅ Saved |
| 4 | Login as **UserB** | ✅ Shows Japan for that day |

### Test 3.5: Member Cannot Set Other's Location

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserC** (Member, not admin) | - |
| 2 | Click tile → Details | ❌ No edit button on UserA/UserB |

---

## SCENARIO 4: Placeholder Members

### Test 4.1: Owner Creates Placeholder

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** (Owner) | - |
| 2 | Go to Groups → Manage Placeholders | - |
| 3 | Create placeholder "Grandma" | ✅ Created |

### Test 4.2: Admin Cannot Create Placeholder

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserB** (Admin) | - |
| 2 | Go to Manage Placeholders | ❌ No "Add" button OR permission denied |

### Test 4.3: All Members See Placeholder in Details

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserC** (Member) | - |
| 2 | Click tile → Details | ✅ "👻 Grandma" visible in list |

### Test 4.4: Owner/Admin Update Placeholder Location

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserB** (Admin) | - |
| 2 | Click tile → Details → Edit on Grandma | - |
| 3 | Set location to Taiwan | ✅ Saved |

### Test 4.5: Member Cannot Update Placeholder

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserC** (Member) | - |
| 2 | Click tile → Details | ❌ No edit button on Grandma |

### Test 4.6: Owner Deletes Placeholder

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** (Owner) | - |
| 2 | Manage Placeholders → Delete Grandma | ✅ Deleted |

### Test 4.7: Admin Cannot Delete Placeholder

| Step | Action | Expected |
|------|--------|----------|
| 1 | Create new placeholder "Uncle" as Owner | - |
| 2 | Login as **UserB** (Admin) | - |
| 3 | Try to delete "Uncle" | ❌ No delete button OR denied |

---

## SCENARIO 5: Events

### Test 5.1: Any Member Creates Event

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserC** (Member) | - |
| 2 | Click tile → Add Event | - |
| 3 | Create "Birthday Party" | ✅ Event created |

### Test 5.2: All Members See Event

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** | - |
| 2 | Click tile → Details | ✅ "Birthday Party" visible |

### Test 5.3: Any Member Can Edit Event

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserB** | - |
| 2 | Click event → Edit | - |
| 3 | Change description | ✅ Saved |

### Test 5.4: Creator/Admin Can Delete Event

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserC** (creator) | - |
| 2 | Delete "Birthday Party" | ✅ Deleted |

### Test 5.5: Non-Member Cannot See Event

| Step | Action | Expected |
|------|--------|----------|
| 1 | Create new event in Family group | - |
| 2 | Login as **UserD** (not in Family) | - |
| 3 | Check calendar | ❌ Event NOT visible |

---

## SCENARIO 6: Inheritance Requests

### Test 6.1: Member Creates Request

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserC** (Member) | - |
| 2 | Request to inherit placeholder "Uncle" | ✅ Request created |

### Test 6.2: Owner Approves Request

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** (Owner) | - |
| 2 | See pending request | - |
| 3 | Approve UserC's request | ✅ Approved |

### Test 6.3: Admin Cannot Approve

| Step | Action | Expected |
|------|--------|----------|
| 1 | UserB (Member) creates request | - |
| 2 | Login as **Admin** (if not owner) | ❌ No approve button |

---

## SCENARIO 7: Profiles & Privacy

### Test 7.1: Group Member Sees Full Profile

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserB** | - |
| 2 | Click on UserA in tile details | ✅ See name, avatar, birthday |

### Test 7.2: Can Only Edit Own Profile

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserA** | - |
| 2 | Go to Profile → Edit birthday | ✅ Saved |
| 3 | Try to edit UserB's profile | ❌ No edit access |

---

## SCENARIO 8: Cross-Group Isolation

### Test 8.1: Create Second Group

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserD** | - |
| 2 | Create group "Work" | ✅ Created |
| 3 | **UserA** joins "Work" | ✅ Joined |

### Test 8.2: Groups Stay Separate

| Step | Action | Expected |
|------|--------|----------|
| 1 | Login as **UserB** (only in Family) | - |
| 2 | Check calendar | ❌ UserD NOT visible |
| 3 | Login as **UserA** (in both groups) | - |
| 4 | Check tile details | ✅ See Family + Work members separated |

### Test 8.3: Location Picker Shows Only Group Placeholders

| Step | Action | Expected |
|------|--------|----------|
| 1 | Create placeholder in "Work" group | - |
| 2 | Login as **UserB** (not in Work) | - |
| 3 | Open location picker | ❌ Work placeholder NOT visible |

---

## Quick Reference: Role Summary

| Action | Owner | Admin | Member |
|--------|:-----:|:-----:|:------:|
| Create group | ✅ | ✅ | ✅ |
| Promote admin | ✅ | ❌ | ❌ |
| Transfer ownership | ✅ | ❌ | ❌ |
| Create placeholder | ✅ | ❌ | ❌ |
| Delete placeholder | ✅ | ❌ | ❌ |
| Update placeholder | ✅ | ✅ | ❌ |
| See placeholders | ✅ | ✅ | ✅ |
| Set member location | ✅ | ✅ | ❌ |
| Create event | ✅ | ✅ | ✅ |
| Delete any event | ✅ | ✅ | ❌ |
| Approve inheritance | ✅ | ❌ | ❌ |
