---
Date: 2026-10-21
Status: Accepted
Related: ADR 013
Triggers:
  - changing opening hours
  - accessing the admin area
  - adding new admin-only features
  - generating a one-time login URL
Topics: store-hours, admin, auth
---

# ADR 018 -- DB-Backed Store Hours and Admin Magic-Link Login

## Context

Store hours were hardcoded as Ruby constants in `StoreHours` (ADR 013). Changing
them required a code edit and a deploy. The store was also running on a fixed
timetable (4pm–7:30pm weekdays, 7:30am–7:30pm weekends) that no longer matched
how the family wanted to use it — the intent shifted to "always open, adjust
only when needed."

An admin area already existed at `/admin/submissions` (HTTP basic auth via
`ADMIN_PASSWORD` env var). That pattern doesn't generalise well to a
browser-friendly hours form, and generating a basic-auth credential from the
command line isn't ergonomic.

## Decision

### Hours are DB-backed with always-open defaults

`StoreHours` no longer has hardcoded open/close constants. Instead, it reads
from Counter rows keyed `hours_<schedule>_open` and `hours_<schedule>_close`,
where `<schedule>` is one of `weekday`, `saturday`, `sunday`, `holiday`. Values
are minutes from midnight (integer).

When no row exists for a key the default is `0` (open) or `1440` (close), which
means always open. This is the production default — the store is open 24/7
unless an admin explicitly sets a narrower window.

`StoreHours.update_hours` writes these Counter rows. `StoreHours.hours_config`
reads them. `window_for` uses the result, so `open?`, `scheduled_open?`, and
`/api/store/status` all stay consistent through the same path they always used.

The Cipher override (`store_open_until` Counter) is unchanged — it still lets
kids unlock the store after hours.

### Admin area protected by signed magic-link

Rather than extend HTTP basic auth, the admin area uses a session set by a
time-limited magic link. The link is generated on the command line:

```
bin/rails admin:login_url
```

This prints a signed URL using `Rails.application.message_verifier("admin-login")`
with a one-hour expiry baked into the payload. Visiting the URL sets
`session[:admin_authenticated]` and redirects to the hours form.

`Admin::BaseController` guards all admin resources. `Admin::SessionsController`
handles the login and logout. The submissions controller retains its own HTTP
basic auth separately — it predates this pattern and the two do not share a
session.

### Store hours form

`/admin/store_hours` shows four fieldsets (weekday, saturday, sunday, holiday
weekday) with HTML time inputs. Schedules at the always-open default are labelled
as such. Saving writes the Counter rows and redirects back.

## Consequences

- Opening hours can be changed without a deploy or a code edit.
- The default in production is always open. Narrower hours require a deliberate
  admin action.
- The magic-link pattern is one-factor (possession of the printed URL). It
  expires in one hour. Anyone with SSH or console access to the server could
  generate one; that is the intended scope.
- `StoreHoursTest` was rewritten to assert always-open defaults and to test
  custom hours by writing Counter rows directly in setup. The store controller
  test pins the old published schedule in its own setup so its specific
  `opens_at`/`closes_at` assertions remain meaningful.
- `RAILS_HOST` can be set to override the URL base in the rake task (default:
  `https://ez-az.net`).
