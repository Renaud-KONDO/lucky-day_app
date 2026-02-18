# Fixing Errors Plan

## Errors Identified

### 1. lib/screens/raffle/raffles_screen.dart
**Critical Errors:**
- **Duplicate `onApply` parameter in `_FilterSheet` class**: Two `onApply` parameters with different signatures defined - this will cause a compile error
  - Line: `final void Function(String? sort, double? min, double? max) onApply;`
  - Line: `final void Function(String? sort, double? min, double? max, String? categoryId, String? categoryName) onApply;`
  
- **Undefined variables in `_openFilters` method**: `catId` and `catName` are used but not defined
  - Should be `categoryId` and `categoryName` from the callback parameters
  
- **Constructor issue**: `currentCategoryId` and `currentCategoryName` parameters in constructor are not properly handled

### 2. lib/providers/raffle_provider.dart
- Redundant imports from logger package (was already fixed - one import was commented out)

## Fix Plan

### Step 1: Fix raffles_screen.dart
- [x] Remove duplicate `onApply` parameter definition - keep only the one with category parameters
- [x] Fix undefined variables in `_openFilters` method (catId -> categoryId, catName -> categoryName)
- [x] Fix constructor to properly handle currentCategoryId and currentCategoryName

### Step 2: Fix raffle_provider.dart  
- [x] Remove redundant import (keep only `import 'package:logger/logger.dart';`) - Already fixed

## Dependencies
- No new dependencies needed
- All files are part of the existing codebase
