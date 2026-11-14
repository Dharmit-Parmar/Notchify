# Noticed Not Touched Log

The following issues and potential improvements were identified during static analysis but not modified in code to adhere strictly to Rule R4 (Scope Lock):

1. **LocalShareDiscovery Stale Peer Eviction**:
   - `LocalShareDiscovery.peersMap` filters out peers older than 60s when producing `activePeers`, but does not proactively remove them from `peersMap`. A periodic eviction loop or maximum map capacity could be added in a future lifecycle phase.

2. **File Stream Writer Error Propagation in Finalize**:
   - In `LocalShareFileStreamWriter.finalize()`, `try? fileHandle.synchronize()` and `try? fileHandle.close()` are used. If an underlying filesystem sync fails, it is currently silenced rather than thrown.

3. **Port Change Server Restart**:
   - In `LocalShareSettings.swift`, modifying `tcpPort` updates `LocalShareDiscovery.shared.localPort`, but does not automatically restart `LocalShareServer.shared` on the new port.

4. **Settings PIN Draft Buffer**:
   - `LocalShareSettingsView.swift` binds `pinCode` directly to `LocalShareSettings.shared.pinCode`. Buffering into a local `@State` draft before writing to Keychain would reduce Keychain write invocations.

5. **LocalShareModule vs LocalShareModuleState Duplication**:
   - Both `LocalShareModule.swift` and `LocalShareModuleState.swift` define similar observable states and callbacks. Consolidation into a single authoritative module controller should be planned as a dedicated refactoring phase.
