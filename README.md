# Bahay Kubo (Flutter demo)

A small Flutter game prototype for an AppDev course. The game shows fruits and vegetables; swipe right for fruits, swipe left for vegetables. Correct swipes add time and coins. The app includes a store and a local leaderboard (saved with SharedPreferences).

## Requirements
- Flutter SDK (stable)
- Android emulator or device (you said Android only)

## How to run
Open PowerShell in project root and run:

```powershell
flutter pub get
flutter run -d emulator-5554
```

If you don't have an emulator id, simply run `flutter run` and pick a device.

## What I included
- `lib/game_engine.dart` — main game logic and persistence
- `lib/screens/` — Home, Game, Store, Leaderboard
- `pubspec.yaml` — includes `provider` and `shared_preferences`
- `test/game_engine_test.dart` — unit test for core logic

## Next steps / improvements
- Add images for fruits/vegetables
- Add animations and sound
- Improve leaderboard persistence and optional remote sync (Firebase)
- Add more store items and skins

