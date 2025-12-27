# Orbit User Acceptance Test (UAT) Plan

This document serves as the master checklist to ensure that refactoring and modularization do not break core functionality.

## 1. Group Management

- [ ] **1.1 Create Group:** Create a group.
  - *Expected:* Appears instantly, user is Owner/Admin.
- [ ] **1.2 Join Request:** Send request to another group.
  - *Expected:* Status "Pending", Owner notified.
- [ ] **1.3 Approve Request:** Owner approves user.
  - *Expected:* User joins, appears in list for both.
- [ ] **1.4 Leave Group (Member):** Regular member leaves.
  - *Expected:* Clean exit, group removed from user list.
- [ ] **1.5 Leave Group (Owner):** Owner tries to leave with members present.
  - *Expected:* **Blocked by UI.** Dialog asks for ownership transfer first.
- [ ] **1.6 Group Deletion:** Last member (Owner) leaves.
  - *Expected:* Group and ALL related events/locations are deleted from database.

## 2. Location & Calendar

- [ ] **2.1 Single Day Location:** Set location for today.
  - *Expected:* Calendar displays the location indicator.
- [ ] **2.2 Range Location:** Set location for 5 days.
  - *Expected:* All 5 days update correctly in real-time.
- [ ] **2.3 Sync Check:** View group calendar on secondary account.
  - *Expected:* Peer changes reflect within 2 seconds.

## 3. Event Management

- [ ] **3.1 Create Event:** Add a group event.
  - *Expected:* Shows on calendar for all; Notification sent.
- [ ] **3.2 RSVP:** RSVP to an event.
  - *Expected:* Status updates; Event creator receives notification.
- [ ] **3.3 Update Event:** Edit title/time.
  - *Expected:* Updates for everyone; Edit history preserved.
- [ ] **3.4 Delete Event:** Delete an event.
  - *Expected:* Removed from all views; Deletion notification sent.

## 4. Notifications

- [ ] **4.1 Real-time Receipt:** Trigger a join request or mention.
  - *Expected:* Red dot on bell icon appears.
- [ ] **4.2 Read/Unread:** Toggle notification state.
  - *Expected:* Dot disappears/reappears; Firestore state updates.

## 5. Reliability & Performance

- [ ] **5.1 Zombie Stream Check:** Open and close Member Management dialog repeatedly.
  - *Expected:* No memory leaks or multiple active listeners in debug console.
- [ ] **5.2 Large Member List:** View group with > 10 members.
  - *Expected:* All members load; no "Internal Assertion" errors in console.
