# iOS trial access gate

The shared trial code is configured in:

`SYCCourses/Sources/SYCCourses/Configuration/TrialAccessConfiguration.swift`

Change `TrialAccessConfiguration.sharedCode` before distributing a trial build. The code is
compiled into the app and can be extracted by a determined person; this gate is only intended to
limit casual access during a small club trial.

Successful access is stored as the `trialAccessUnlocked` Boolean in `UserDefaults`. It normally
persists across launches on that installation.

## Reset during development

In the Xcode scheme editor, add this argument under **Run → Arguments Passed On Launch**:

`-resetTrialAccess`

The argument is handled only in `DEBUG` builds. Remove or disable the argument after testing the
locked launch state, otherwise the app will reset access on every debug launch.
