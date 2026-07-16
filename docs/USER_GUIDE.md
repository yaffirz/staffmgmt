# Staff Portal — User Guide (Features & Roles)

A plain-English guide to what the Staff Portal does and what each role can see and
do. For build/deploy steps see **[BUILD_APK.md](BUILD_APK.md)**.

---

## 1. What the app is

The Staff Portal is a staff-management system for a multi-brand restaurant/hospitality
group. It tracks employees across **brands → stores → positions**, controls who can
do what by **role**, and keeps a full **audit trail** of every change. It runs as a
web app and as an Android app from the same codebase.

- **Backend:** FastAPI + PostgreSQL (Docker).
- **Frontend:** Flutter (web + Android).
- Sign-in is by username/password; the app remembers your session (JWT, ~12h).

---

## 2. Roles at a glance

Everyone signs in with one **primary role**. A **Super Admin** can also grant a user
**additional roles** — that user then sees the combined tools of all their roles
("effective roles").

| Role | In one line | Key screens |
|---|---|---|
| **Super Admin** | Full control; the only role that can grant multi-roles; sees every note | Everything |
| **Admin** | Runs the org: staff, structure, users, settings, audit | Employees, Brands & Stores, Users & Roles, Status Changes, Audit Logs, Form Settings, Settings |
| **HR** | Hiring and staff lifecycle | New Hire, Employees, Status Changes, Staff Notes |
| **Area Manager (AM)** | Manages the stores in their brand(s) | My Cluster, Cross-store Assignments, Staff Notes |
| **IT** | "Admin-lite": provisions/updates staff & reads notes; receives alerts | Employees, Staff Notes (+ the notification bell) |

### What each role can do (details)

**Super Admin**
- Everything below, plus:
- **Assign additional roles** to any user (e.g. make someone *HR + IT*). No one else can.
- **Sees every staff note**, regardless of who wrote it or how it's shared.

**Admin**
- Create/edit/delete **employees**; bulk import; edit MAG cards; mark rows reviewed.
- Manage the org: **brands, stores, positions** (add/edit/bulk/delete with
  referential-integrity protection).
- Manage **users & roles** (but *cannot* grant additional roles — that's Super Admin only).
- **Status changes** (promote/demote/terminate/reactivate).
- **Settings** (feature toggles) and **Audit Logs**.
- Configure the **new-hire form** (Form Settings).

**HR**
- **New Hire** wizard (data entry) and **Employees** (view/update).
- **Status changes** (promote/demote/terminate/reactivate).
- **Staff Notes**.

**Area Manager (AM)** — access is **brand-scoped**: an AM covers one or more brands
(assigned by an Admin/Super Admin), and their "cluster" is every store in those brands.
- **My Cluster:** see the stores they manage and the staff in each.
- **Move staff:** change a staffer's **primary** store to another store in the cluster.
- **Request staff:** search all staff by name and submit a request to bring someone in
  (queued for an admin to action).
- **Cross-store Assignments:** add a cluster staffer to **another** store in the cluster
  (they keep all their stores — see the "stores accumulate" note below).
- **Staff Notes** for their people.

**IT** ("admin-lite")
- View and update **employees** and open **staff pages**; read/write **staff notes**
  (subject to note visibility).
- Receives the **notification alerts** it needs (see §5).
- **Cannot** manage users, settings, org structure, or delete employees.

> **Multi-role example:** a user set to primary **HR** with an additional **IT** role
> sees the union of both dashboards and can do everything HR and IT can do. The list of
> app accounts shows this as "Also: IT" under the person.

---

## 3. Core concepts

- **Brand → Store → Position.** Every employee has a **primary store** (which belongs to
  a brand) and a **position** (a job title within that brand, e.g. Cashier → Shift
  Supervisor → Store Manager).
- **Additional stores accumulate.** When a staffer is assigned to another store they are
  added to it — they keep their primary and every store they've been assigned to. Staff
  are only removed from stores when they're **terminated**.
- **Reviewed flag.** Any employee row can be marked **reviewed** (a shared, visible tick
  used to signal "this person's setup is done"). Marking it notifies the brand's Area
  Manager (see §5).
- **Employment status.** `active` or `terminated`. Terminating is reversible via
  **Reactivate**.

---

## 4. Features by area

### 4.1 Sign in
- Username + password. The **"Change"** link on the login screen lets you point the app
  at a different backend server (useful for the Android app — see BUILD_APK.md).

### 4.2 Dashboard
- Shows only the **modules for your role(s)**. A multi-role user sees the combined set.
- The **notification bell** (top bar) is always available.

### 4.3 Employees
- **New Hire wizard:** guided data entry; the fields shown are controlled by **Form
  Settings**.
- **All Employees table:** search (name, payroll, store, position, email…), a **reviewed**
  toggle per row, inline **MAG card** editing (admins), **edit** (re-opens the wizard),
  **delete** (admins), a **Notes** shortcut, and **additional stores**.
- **Bulk import:** CSV template download + upload/paste for brands, stores, positions,
  and employees.

### 4.4 Brands & Stores hub
- Manage **brands, stores, positions**: add, edit, bulk CSV import, multi-select delete.
- Deletion is **blocked** if something still references the item (e.g. a brand with stores).

### 4.5 Users & Roles (Admin / Super Admin)
- Create/edit/delete app accounts: username, unique email, password, **role**.
- **Area Manager** accounts get a **brand picker** (which brands they cover).
- **Additional roles** picker appears for **Super Admin** only (multi-role).
- Accounts are grouped by role; multi-role users show "Also: …".

### 4.6 My Cluster (Area Manager)
- Brand-grouped **store cards**, each listing its staff (managers/supervisors first).
  Staff who are here via an additional-store link show an **"Also covers"** tag.
- Per card: **Move staff** (change primary store within the cluster) and **Request staff**
  (name search → queue a request to admins).
- Tap a staffer to open their **staff page**.

### 4.7 Cross-store Assignments (Area Manager)
- Pick a staffer in your cluster → pick a store they're **not** already in → **Assign**.
  Adds an additional store (accumulative). Notifies IT.

### 4.8 Individual staff page
Reached from Employees, My Cluster, the store drilldown, the Staff Notes feed, and
notification click-throughs.
- **Header:** name, payroll, position, store, brand, and a **Terminated** badge if applicable.
- **Employment section** (Super Admin / Admin / HR only): current position, and actions —
  **Promote**, **Demote** (pick a new position + optional reason), **Terminate** /
  **Reactivate** — plus a **history** of all status changes (including store transfers).
- **Notes:** add a note and choose **who can see it** (see §4.9); delete your own notes.

### 4.9 Staff Notes & visibility
- Notes are attached to a specific employee. When writing one you choose its audience:
  - **Private** (default) — only **you** and a **Super Admin** can see it.
  - **Roles** — also visible to chosen roles (HR / Admin / Area Manager).
  - **Brands** — also visible to the **Area Managers of the chosen brand(s)**; the picker
    defaults to your own brand.
- **Staff Notes** tile → an **all-notes feed** of every note *you're allowed to see*
  across all staff; each row opens that person's page.

### 4.10 Status Changes feed
- The **Status Changes** tile → a feed of recent promotes/demotes/terminations/reactivations
  and store transfers across staff, each linking to the person's page.

### 4.11 Notifications (bell)
- The bell shows an **unread count**; the dropdown lists your notifications newest-first.
- Read state is **per-user** — marking one read only affects you.
- Clicking a notification marks it read and **jumps to the relevant place** (the store,
  or the staffer's page).
- **Mark all read** clears them.

### 4.12 Audit Logs (Admin / Super Admin)
- The **Audit Logs** tile → the admin mini-console: a searchable feed of every change
  (Created / Updated / Deleted), who made it, when, and a **before/after** detail view.
  Filter by table (Employees, Notes, Notifications, Users, Settings).

### 4.13 Settings — feature toggles (Admin / Super Admin)
- **Area Managers can move staff** — when off, AMs can't change a staffer's primary store.
- **Staff notes enabled** — when off, no one can add/edit notes (existing notes stay visible).

---

## 5. Automatic notifications (triggers)

The system sends alerts automatically:

| When this happens | Who gets notified | Message |
|---|---|---|
| A staffer is **marked reviewed** | The **Area Manager(s)** of that brand | "…account is reviewed. Please check them at <store> in about an hour." |
| An AM **assigns** a staffer to another store | **IT** | "<name> assigned to <store> by <AM>." |
| **Promoted** | **IT** | "<name> promoted to <position> by <who>." |
| **Demoted** | **IT** | "<name> role changed…" |
| **Terminated** | **IT** | "<name> terminated by <who>." |
| An AM **moves** a staffer's primary store | **Admins** | "<name> moved to <store> by <AM>." |
| An AM **requests** a staffer for a store | **Admins** | "<AM> requested <name> for <store>." |

Notifications appear in the recipient's **bell** and are visible to whoever holds the
target role (Super Admin also sees Admin-targeted ones).

---

## 6. Who-can-see-what (quick reference)

- **Employees list / management:** Super Admin, Admin, HR, IT.
- **Brands/Stores/Positions & Users & Roles & Settings & Audit Logs:** Super Admin, Admin.
- **Status changes (promote/demote/terminate):** Super Admin, Admin, HR.
- **My Cluster / Move / Request / Cross-store:** Area Manager.
- **Staff page + notes:** Super Admin, Admin, HR, Area Manager (their cluster), IT.
- **Grant additional (multi) roles:** Super Admin only.

---

## 7. Glossary

- **Cluster** — all the stores in an Area Manager's assigned brand(s).
- **Primary store** — an employee's home store (one only).
- **Additional store** — an extra store a staffer also covers (accumulates).
- **MAG card** — the staff card/number tracked on each employee.
- **Reviewed** — a shared tick meaning a row has been checked/provisioned.
- **Effective roles** — a user's primary role plus any additional roles.
