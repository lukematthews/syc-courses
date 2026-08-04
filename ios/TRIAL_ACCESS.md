# Legacy trial access

The compiled shared-code system has been removed. Fresh installations do not accept
`SYC-TRIAL-26`; activation now uses the server-backed club licensing flow documented in
[`../LICENSING_ARCHITECTURE.md`](../LICENSING_ARCHITECTURE.md).

On upgrade, an existing `trialAccessUnlocked = true` preference is migrated once to an atomic,
explicit legacy record limited to the bundled SYC snapshot. It is not a signed entitlement and does
not grant future packs or update services. The old preference is removed only after the record is
durably written.
