# app_armor example

Shows AppArmor's runtime protection, screen privacy, vault, clipboard and
session guard in a small wallet app.

```sh
flutter run
```

Preview the loader and the blocked screens without a rooted device:

```sh
flutter run --dart-define=ARMOR_PREVIEW=checking
flutter run --dart-define=ARMOR_PREVIEW=blocked --dart-define=ARMOR_LANG=ar
flutter run --dart-define=ARMOR_PREVIEW=custom   # blockedScreenBuilder
```
