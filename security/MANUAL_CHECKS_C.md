# Manual Verification Guide — Stage C: Notes & Contacts At-Rest Encryption (SEC-A-1 & SEC-A-2)

This document provides step-by-step instructions for manually verifying at-rest encryption of notes and contacts using CryptoKit AES-256-GCM.

---

## 1. At-Rest Encryption Verification (SEC-A-1: Notes)
- **What was implemented**: `notes.txt` is stored encrypted using CryptoKit AES-256-GCM with a 256-bit key protected by macOS Keychain. The on-disk file begins with magic bytes `NOTCHENC1\x01` followed by the authenticated AES-GCM ciphertext.
- **Verification Steps**:
  1. Open Notch and type sensitive notes into the Notes scratchpad:
     ```
     Confidential Meeting Notes 2026: Project Top Secret
     ```
  2. Wait 2 seconds for debounced save to disk.
  3. Inspect `notes.txt` on disk in terminal:
     ```bash
     cat "$HOME/Library/Application Support/NotchApp/notes.txt"
     ```
  4. Expected Result: The file contains binary data starting with `NOTCHENC1`. The string "Confidential Meeting Notes" is completely absent from the file.
  5. Verify POSIX permissions:
     ```bash
     stat -f "%Lp" "$HOME/Library/Application Support/NotchApp/notes.txt"
     ```
  6. Expected Result: Exactly `600` (read/write by owner only).

---

## 2. At-Rest Encryption Verification (SEC-A-2: Contacts)
- **What was implemented**: `contacts.json` is stored encrypted with `NOTCHENC1` header and AES-256-GCM ciphertext.
- **Verification Steps**:
  1. Add a contact in the Telegram widget (e.g. name: "Alice Security", handle: "@alice_test").
  2. Inspect `contacts.json` on disk:
     ```bash
     cat "$HOME/Library/Application Support/NotchApp/contacts.json"
     ```
  3. Expected Result: The file contains binary data starting with `NOTCHENC1`. Contact names, phone numbers, and handles are encrypted and cannot be found in plaintext.
  4. Verify POSIX permissions:
     ```bash
     stat -f "%Lp" "$HOME/Library/Application Support/NotchApp/contacts.json"
     ```
  5. Expected Result: Exactly `600`.

---

## 3. Seamless Legacy Plaintext Migration
- **What was implemented**: When an unencrypted `notes.txt` or `contacts.json` from an older version of Notch is read, `EncryptedFileStore` detects the absence of the `NOTCHENC1` header, reads the plaintext, and immediately rewrites the file encrypted with POSIX `0600` permissions.
- **Verification Steps**:
  1. Quit NotchApp.
  2. Write a plaintext note manually to `$HOME/Library/Application Support/NotchApp/notes.txt`:
     ```bash
     echo "Plaintext legacy note from 2025" > "$HOME/Library/Application Support/NotchApp/notes.txt"
     ```
  3. Launch NotchApp and open the Notes tab.
  4. Verify that "Plaintext legacy note from 2025" displays correctly in the UI.
  5. Inspect the file on disk:
     ```bash
     head -c 9 "$HOME/Library/Application Support/NotchApp/notes.txt"
     ```
  6. Expected Result: The output is `NOTCHENC1`. The file was transparently migrated to encrypted at-rest storage without user intervention or data loss.

---

## 4. Tamper Detection & Integrity Verification
- **What was implemented**: AES-256-GCM uses a 128-bit authentication tag. Any tampering, byte corruption, or truncation causes `AES.GCM.open` to fail, preventing malicious injection of manipulated data.
- **Verification Steps**:
  1. Run verification test 101:
     ```bash
     swift run NotchTests | grep "At-Rest Encryption"
     ```
  2. Expected Result: Subtest 3 asserts that flipping 1 byte in the ciphertext causes decryption to throw an authentication error.

---

## 5. Keychain Key Protection
- **What was implemented**: The 256-bit symmetric encryption key is stored securely in macOS Keychain under account `"notch_file_encryption_key"` with accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- **Verification Steps**:
  1. Inspect Keychain item (without displaying raw secret):
     ```bash
     security find-generic-password -s "com.notch.NotchApp" -a "notch_file_encryption_key" >/dev/null && echo "Keychain key present"
     ```
  2. Expected Result: Key exists and is protected by macOS Keychain Services.
