# SilentNight — Mac Mini TestFlight Pipeline

> **AGENT TASK** (Exa / Max / any mini agent reading this):
> The mini is *almost* ready to ship SilentNight builds to TestFlight on its own.
> Two one-time setup steps remain. They are detailed in the **"Agent: do this"** section below.
> When both are done, mark this file with `STATUS: READY` on the first line and post a
> comment back to Fizzy card #1158 confirming.

STATUS: READY

> **RESOLVED 2026-05-30 (Exa):** The two "missing" steps below (manual Apple Distribution
> `.p12` import + macOS login password for `set-key-partition-list`) are NOT required.
> Cloud-managed signing via the ASC API key (`-allowProvisioningUpdates` +
> `-authenticationKeyPath/ID/IssuerID`) provisions the **Apple Distribution: Steve Schramm
> (FZH8LG6FP4)** cert automatically at export time. The `errSecInternalComponent` wall only
> appears over **headless SSH** — when the build runs inside Steve's GUI login session on the
> mini (where these agents run), the keychain is unlocked and codesign succeeds.
> Proven today three ways: Setlist build 84 uploaded, SilentNight build 1 uploaded, and a
> fresh verification archive+export producing a distribution-signed IPA
> (`Authority=Apple Distribution: Steve Schramm (FZH8LG6FP4)`). Steps 1 & 2 below are kept
> for the headless-SSH fallback only.

## Already done (verified 2026-05-30)
- ✅ Repo cloned: `~/Projects/SilentNight` synced to `origin/main` (commit `aded5e1`).
- ✅ Ship script: `~/bin/silentnight-ship.sh` (executable). Pulls latest, archives Release, exports IPA, uploads via altool.
- ✅ Xcode 26.5 installed at `~/Applications/Xcode-26.5.0.app`.
- ✅ ASC API key in place: `~/.appstoreconnect/private_keys/AuthKey_6XV7GUPKCH.p8` (key ID `6XV7GUPKCH`, issuer `4cffb712-48ec-4edb-9a9c-6c08933589e5`). Verified working for ASC API calls.
- ✅ Apple Development cert is in the login keychain.

## What's missing
- ❌ **Apple Distribution cert** (mini only has Apple Development; TestFlight uploads require Apple Distribution from team `FZH8LG6FP4`).
- ❌ **Headless codesign** — over SSH, `codesign` returns `errSecInternalComponent` because the login keychain is locked and/or private keys are not partition-listed for codesign.

## Agent: do this

### Step 1 — Get the Distribution cert onto the mini
This requires Steve's MacBook Pro because the Distribution cert + its private key live in the MBP login keychain and exporting the private key triggers a Keychain Access GUI prompt that cannot be automated headlessly.

**What the agent should do:**
1. Post a Fizzy comment on card **#1158** addressed to Steve with the following instructions, then wait:
   ```
   Steve — to finish mini TestFlight setup, please run these on your MacBook Pro:
   
   1. Open Keychain Access → login keychain → My Certificates.
   2. Right-click "Apple Distribution: Steve Schramm (FZH8LG6FP4)" → Export…
   3. Save as ~/Desktop/AppleDist.p12, set a password (any one you'll remember briefly).
   4. Run:
        scp ~/Desktop/AppleDist.p12 steveschramm@100.100.6.64:~/AppleDist.p12
      and post the .p12 password as a private note here.
   5. After confirming, run on MBP: `rm ~/Desktop/AppleDist.p12`
   ```
2. When Steve responds with the password (call it `$P12_PASS`), the agent runs on the mini:
   ```
   security import ~/AppleDist.p12 \
     -P "$P12_PASS" \
     -k ~/Library/Keychains/login.keychain-db \
     -T /usr/bin/codesign -T /usr/bin/security
   rm ~/AppleDist.p12
   security find-identity -p codesigning -v   # confirm Apple Distribution shows up
   ```

### Step 2 — Make codesign work over SSH
This requires Steve's macOS login password (the same one used to log into the Mac). The agent should:

1. Ask Steve (Fizzy comment on #1158) for his **macOS login password** — note that it is needed only to run `security set-key-partition-list` so codesign can access the keys non-interactively. Suggest he rotate it after if he's uncomfortable. (Alternative if he refuses: he can run the command himself in person.)
2. With `$LOGIN_PW` in hand, run on the mini:
   ```
   security unlock-keychain -p "$LOGIN_PW" ~/Library/Keychains/login.keychain-db
   security set-key-partition-list \
     -S apple-tool:,apple:,codesign: \
     -s -k "$LOGIN_PW" \
     ~/Library/Keychains/login.keychain-db
   ```
3. Verify by running a dry archive:
   ```
   cd ~/Projects/SilentNight
   xcodebuild archive \
     -project SilentNight.xcodeproj -scheme SilentNight -configuration Release \
     -destination "generic/platform=iOS" -archivePath /tmp/sn-verify.xcarchive \
     -allowProvisioningUpdates \
     -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_6XV7GUPKCH.p8 \
     -authenticationKeyID 6XV7GUPKCH \
     -authenticationKeyIssuerID 4cffb712-48ec-4edb-9a9c-6c08933589e5 \
     DEVELOPMENT_TEAM=FZH8LG6FP4
   ```
   This should reach `** ARCHIVE SUCCEEDED **` without codesign errors.

### Step 3 — Wrap up
- Update line 1 of this file from `STATUS: SETUP_PENDING` to `STATUS: READY`.
- Commit and push (`git add MINI_TESTFLIGHT_SETUP.md && git commit -m "mini: TestFlight pipeline ready" && git push`).
- Post on Fizzy #1158: "Mini TestFlight pipeline is live. Future updates ship with `ssh mini ~/bin/silentnight-ship.sh`."
- Optional next step: add a cron entry on the mini that auto-runs `silentnight-ship.sh` when new commits land on `origin/main` (debounce: don't ship more than once per hour).

## Future shipping (once setup is done)
```
ssh mini ~/bin/silentnight-ship.sh
```
Runtime: ~3 min. Output ends with `UPLOAD SUCCEEDED with no errors`.
