# Epic 08 — Deferred (post-v1 / paid-tier)

Features the portal web frontend has, that the iOS client may eventually want, but that are **deliberately out of v1** — each blocked on a paid Apple entitlement or a server change. Kept here (not dropped) so the backlog is complete and the trigger to revisit each is explicit.

| Feature | Why deferred | Unblocks when… |
| --- | --- | --- |
| [Passkey authentication](passkey-authentication.md) | Native passkeys need the **Associated Domains** entitlement (managed; paid Apple Developer Program only) + an AASA file + server RP config | You take the paid tier; iOS's Face-ID-gated Keychain JWT is the v1 substitute |
| [Push notifications](push-notifications.md) | **APNs** is paid-tier only | You take the paid tier; v1 uses foreground polling + the in-app inbox |
| [Quota display](quota-display.md) | **No portal-scoped quota endpoint** exists (admin-only); over-quota still returns 201 | The server adds a portal quota endpoint |

## Explicitly out of scope (not deferred — different audience)

The **admin request queue** — approve/deny, batch actions, invitation management, user management, quota configuration (`web/src/routes/requests-admin/**`) — is **not** an iOS feature. A portal token cannot call admin endpoints, and these belong to the admin audience who use the web portal. No stubs are created for them. (If an admin ever wants phone-side approvals, that's a separate app/auth path, not this portal-companion.)
