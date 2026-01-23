## Automated Setup (Recommended)
We have provided an automation script in the repository to install the "Save to Cortex" service automatically.

1. Open Terminal.
2. Navigate to the project root and run:
   ```bash
   chmod +x scripts/setup_cortex_service.sh
   ./scripts/setup_cortex_service.sh
   ```
3. The service **"Save to Cortex"** will be installed to `~/Library/Services/`.
4. Go to **System Settings > Keyboard > Shortcuts > Services** > **Text** to verify it is enabled and assign a keyboard shortcut (e.g. `Cmd + Shift + .`).

---

## Manual Setup (Alternative)
If you prefer to create the Shortcut manually:

1. Open the **Shortcuts** app on your Mac.
2. Click **File > New Shortcut** (Cmd+N).
3. Name the shortcut `Save to Cortex` (in the window title bar).

## 2. Configure the Actions
Add the following actions in order:

### A. Receive Input
- In the right sidebar "Search Actions", search for **"Receive Input"** (or look under "Shortcut Details" > "Use as Quick Action").
- Check **Use as Quick Action**.
- Configure: "Receive **Text** and **Rich Text** input from **Quick Actions**, **Services Menu**".

### B. URL Encode (Optional but Recommended)
- Search for **"URL Encode"**.
- Drag it below "Receive Input".
- It should default to `URL Encode [Shortcut Input]`. This handles special characters in selected text.

### C. Open URL
- Search for **"Open URL"**.
- In the URL field, type:
  ```
  cortex://capture?text=
  ```
- Right after the `=`, right-click and select **Insert Variable**, then choose **URL Encoded Text** (result from step B) or **Shortcut Input** (if you skipped step B).
- Append any default parameters if desired, e.g.:
  ```
  &type=article&title=Quick Capture
  ```
- The final URL should look like:
  `cortex://capture?text=[URL Encoded Text]&type=article`

## 3. Assign a Keyboard Shortcut
1. Click the **Information (i)** icon in the top right sidebar.
2. Under **"Add Keyboard Shortcut"**, click "Run with...".
3. Press your desired key combination (e.g., `Cmd + Shift + .` or `Cmd + Option + C`).

## 4. Usage
1. Highlight text in any app (Safari, Notes, etc.).
2. Press your keyboard shortcut.
3. Cortex will open with the Capture Dialog pre-filled.
