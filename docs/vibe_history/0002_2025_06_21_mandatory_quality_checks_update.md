# Task: Update Copilot Instructions for Mandatory Quality Checks
**Date**: 2025-06-21
**Completed by**: GitHub Copilot

## What Was Requested
- Update the copilot instructions file to make sure before finishing tasks, always runs lint, analyze and test

## What Was Done
- Strengthened the language in the "Task Completion Protocol" section to be more emphatic about quality checks
- Made the three quality checks (lint, analyze, test) **MANDATORY** with explicit requirements
- Added references to the Makefile's `make quality-check` command as the recommended approach
- Updated "Testing Requirements" section to mark linting and testing as **MANDATORY**
- Added clear success criteria with checkmarks for each quality check
- Emphasized that tasks must **NEVER** be completed with failing quality checks

## Technical Details
- **Enhanced Task Completion Protocol**: Added explicit MANDATORY requirements and NEVER statements
- **Quality Check Requirements**: 
  - ✅ **Pint**: Zero styling issues
  - ✅ **PHPStan**: Zero static analysis errors  
  - ✅ **Tests**: All tests must pass
- **Makefile Integration**: Referenced `make quality-check` as the preferred method
- **Stronger Language**: Changed from "run" to "MANDATORY" and added "NEVER complete" warnings

## Verification
- **Linting**: ✅ `./vendor/bin/pint` - 30 files passed, no styling issues
- **Static Analysis**: ✅ `./vendor/bin/phpstan analyse` - No errors found
- **Tests**: ✅ `php artisan test` - 2 tests passed (2 assertions)
- **Complete Quality Check**: ✅ All checks passed successfully

## Notes for Future
- The instructions now make it crystal clear that quality checks are not optional
- Future Copilot sessions will have explicit guidance to never skip these checks
- The three-check verification process is now standardized and mandatory
- Makefile provides convenient `make quality-check` command for complete verification

## Files Modified
- `.github/copilot-instructions.md` - Enhanced task completion protocol with mandatory quality checks
