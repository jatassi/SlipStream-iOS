---
epic: 01-foundations
status: unrefined
type: feature
v1: true
plan: "Plan 2+ (RootView shell in Plan 1)"
---

# App shell & primary navigation

**Intent:** Give the app a consistent top-level frame so the user can move between Home, Search, Library, and Settings from any screen.

## Summary
Mirrors the web `portal-layout` + `portal-header`: persistent chrome wrapping every authenticated screen, hosting the global search entry, a Library link, the notification bell, a settings affordance, the live downloads strip, and the routed content area. Must be size-class adaptive (one layer for iPhone / iPad / Mac).

## In scope
- Primary navigation (tab bar and/or `NavigationSplitView`) across Home, Search, Library, Settings, and Detail.
- Header chrome: global search entry, [notification bell](../06-notifications/inbox-bell-badge.md), settings entry.
- Hosts the [downloads strip](../05-downloads/downloads-strip.md) and (when enabled) the passkey-promotion prompt.
- Auth-guarded routing (only authenticated users reach portal screens).

## Source of truth (web portal)
- `web/src/components/portal/portal-layout.tsx`, `portal-header.tsx`; App-shell area.

## iOS notes
- `NavigationSplitView` / `TabView`, size-class adaptive (iPad adaptivity = the Mac experience under Designed-for-iPad).
- Define the route/deep-link information architecture for detail screens and settings sections.

## Open questions
- [ ] Settings as a tab, or a header/toolbar button (as on web)?
- [ ] The web's header search has a visibility quirk (operator-precedence) — decide intended per-screen search visibility.

## Dependencies
- [Auth route guard](../02-authentication/session-persistence-keychain.md); consumed by most feature epics.
