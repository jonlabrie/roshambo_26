# Task 3: NorenSway Culling — Report

**Status:** DONE

**Commit SHA:** b8c2406

**Test Summary:** 1844 tests passed, 0 failed

**Changes Made:**
- Added `AmbientBudget` and `AmbientConfig` requires to NorenSway.client.luau
- Implemented camera-distance and view-direction culling in the Heartbeat loop
- Panels now only animate when within range and facing the camera
- Animation pose calculations preserved exactly (pure function of os.clock())

**Concerns:** None

**Gates Passed:**
- stylua: ✓ (formatting)
- selene: ✓ (0 errors, 0 warnings)
- lune run tests/run: ✓ (1844/1844 tests)
- rojo build: ✓ (build successful)
