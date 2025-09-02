# EduNest Version Management Guide

This guide explains how to manage versions for EduNest releases, including first-time installation and updates.

## Table of Contents
1. [Version Management Overview](#version-management-overview)
2. [First-Time Installation Process](#first-time-installation-process)
3. [Update Process](#update-process)
4. [Version Numbering Convention](#version-numbering-convention)
5. [Files to Update for New Versions](#files-to-update-for-new-versions)
6. [Testing Version Updates](#testing-version-updates)
7. [Troubleshooting](#troubleshooting)

## Version Management Overview

EduNest uses a dual version system:
- **App Version**: Managed in `pubspec.yaml` (e.g., `1.0.0+1`)
- **Display Version**: Managed in `whats_new_dialog.dart` (e.g., `1.1.0`)

The app checks for updates from a GitHub-hosted JSON file and shows appropriate dialogs to users.

## First-Time Installation Process

### 1. Initial Setup

When creating a new release for first-time installation:

1. **Update pubspec.yaml**:
   ```yaml
   version: 1.0.0+1  # Format: major.minor.patch+build
   ```

2. **Update whats_new_dialog.dart**:
   ```dart
   const String currentVersion = '1.0.0'; // Update for each release
   ```

3. **Create latest.json** (host on GitHub):
   ```json
   {
     "version": "1.0.0",
     "download_url": "https://github.com/Ranojitdas/EduNest-desktop/releases/download/v1.0.0/EduNestInstaller.exe",
     "windows": {
       "download_url": "https://github.com/Ranojitdas/EduNest-desktop/releases/download/v1.0.0/EduNestInstaller.exe"
     },
     "release_notes": [
       "Initial release",
       "Core features implemented",
       "Desktop application ready"
     ]
   }
   ```

4. **Update WhatsNewDialog items**:
   ```dart
   static const List<String> whatsNewItems = [
     'Initial release',
     'Core features implemented',
     'Desktop application ready'
   ];
   ```

### 2. Build and Release

1. **Build the application**:
   ```bash
   flutter build windows --release
   ```

2. **Create installer** using the existing `.iss` files

3. **Upload to GitHub Releases** with tag `v1.0.0`

4. **Update the latest.json** file in the GitHub repository

## Update Process

### 1. Version Increment Strategy

Follow semantic versioning:
- **Major** (1.0.0 → 2.0.0): Breaking changes
- **Minor** (1.0.0 → 1.1.0): New features, backward compatible
- **Patch** (1.0.0 → 1.0.1): Bug fixes

### 2. Files to Update

#### A. pubspec.yaml
```yaml
version: 1.1.0+2  # Increment both version and build number
```

#### B. lib/widgets/whats_new_dialog.dart
```dart
const String currentVersion = '1.1.0'; // Update for each release

// Update the what's new items
static const List<String> whatsNewItems = [
  'New feature A',
  'Bug fix B',
  'Performance improvement C'
];
```

#### C. GitHub latest.json
```json
{
  "version": "1.1.0",
  "download_url": "https://github.com/Ranojitdas/EduNest-desktop/releases/download/v1.1.0/EduNestUpdate.exe",
  "windows": {
    "download_url": "https://github.com/Ranojitdas/EduNest-desktop/releases/download/v1.1.0/EduNestUpdate.exe"
  },
  "release_notes": [
    "New feature A",
    "Bug fix B",
    "Performance improvement C"
  ]
}
```

### 3. Update Workflow

1. **Increment versions** in all files listed above
2. **Build the application**:
   ```bash
   flutter build windows --release
   ```
3. **Create update installer** (EduNestUpdate.exe)
4. **Upload to GitHub Releases** with tag `v1.1.0`
5. **Update latest.json** in GitHub repository
6. **Test the update flow** on a machine with the previous version

## Version Numbering Convention

### Format: `major.minor.patch+build`

- **major**: Breaking changes, major features
- **minor**: New features, backward compatible
- **patch**: Bug fixes, minor improvements
- **build**: Build number (auto-incremented)

### Examples:
- `1.0.0+1` → First release
- `1.0.1+2` → Bug fix release
- `1.1.0+3` → New feature release
- `2.0.0+4` → Major version with breaking changes

## Files to Update for New Versions

### 1. Primary Files
- `pubspec.yaml` - App version and build number
- `lib/widgets/whats_new_dialog.dart` - Display version and what's new items

### 2. GitHub Repository
- `latest.json` - Update information for the app
- GitHub Releases - Upload new installer/update files

### 3. Optional Files
- `README.md` - Update version information
- `CHANGELOG.md` - Document changes (if maintained)

## Testing Version Updates

### 1. Test Update Flow

1. **Install previous version** on a test machine
2. **Update latest.json** with new version
3. **Launch the app** and verify update dialog appears
4. **Test the download** and installation process
5. **Verify What's New dialog** shows after update

### 2. Test What's New Dialog

1. **Clear SharedPreferences** for `last_seen_version`
2. **Launch the app** and verify What's New dialog appears
3. **Close and reopen** the app to ensure it doesn't show again

### 3. Test Version Comparison

The app uses this logic to compare versions:
```dart
bool _isNewerVersion(String latest, String current) {
  List<int> parseVersion(String v) =>
      v.replaceAll(RegExp(r'[^0-9.]'), '')
          .split('.')
          .where((e) => e.isNotEmpty)
          .map(int.parse)
          .toList();
  
  final latestParts = parseVersion(latest);
  final currentParts = parseVersion(current);
  
  for (int i = 0; i < latestParts.length; i++) {
    if (i >= currentParts.length) return true;
    if (latestParts[i] > currentParts[i]) return true;
    if (latestParts[i] < currentParts[i]) return false;
  }
  return false;
}
```

## Troubleshooting

### Common Issues

1. **Update dialog not showing**:
   - Check `latest.json` format and URL
   - Verify version comparison logic
   - Check network connectivity

2. **What's New dialog not showing**:
   - Clear `last_seen_version` from SharedPreferences
   - Verify `currentVersion` matches in code

3. **Version mismatch**:
   - Ensure `pubspec.yaml` and `whats_new_dialog.dart` versions are in sync
   - Check that `latest.json` version is higher than current

### Debug Steps

1. **Check current version**:
   ```dart
   print('Current version: $currentVersion');
   ```

2. **Check latest version**:
   ```dart
   print('Latest version: $latestVersion');
   ```

3. **Check version comparison**:
   ```dart
   print('Is newer: ${_isNewerVersion(latestVersion, currentVersion)}');
   ```

## Recent Major Implementations (Ready for v1.1.0)

### Performance Optimizations
- **Comprehensive Caching System**: Multi-layer caching for assignment marks, midsem marks, attendance data
- **Cache Invalidation**: Smart cache clearing when academic path changes
- **Database Optimization**: Migrated from professor_attendance to class_attendance_sessions (6x faster)
- **Request Deduplication**: Eliminated excessive profile API requests

### Critical Bug Fixes
- **Assignment Marks Filtering**: Fixed cross-college subject display issues
- **Midsem Marks System**: Complete overhaul with proper filtering and notifications
- **Home Screen Cache**: Fixed stale data issues during logout/login cycles
- **Student Profile Linking**: Preserved admin-entered names during profile linking

### New Features
- **Enhanced Academic Path Filtering**: Subjects now filter by current college/branch/semester
- **Improved Notification System**: Comprehensive triggers for marks updates
- **Admin Panel Optimizations**: Reduced API calls and improved performance
- **Robust Error Handling**: Better user experience with proper error management

## Quick Reference

### For New Release (v1.1.0):
1. Update `pubspec.yaml` version to `1.1.0+2`
2. Update `whats_new_dialog.dart` currentVersion to `1.1.0`
3. Update `whats_new_dialog.dart` whatsNewItems with new features
4. Update GitHub `latest.json`
5. Build and release
6. Test update flow

### For Hotfix:
1. Increment patch version in both files
2. Update `latest.json` with new version
4. Test on previous version

### Version URLs:
- **Update JSON**: `https://raw.githubusercontent.com/Ranojitdas/EduNest-desktop/main/latest.json`
- **Download Base**: `https://github.com/Ranojitdas/EduNest-desktop/releases/download/v{version}/`

---

**Note**: Always test the update flow on a machine with the previous version before releasing to ensure a smooth user experience. 