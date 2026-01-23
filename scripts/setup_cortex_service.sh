#!/bin/bash
# Configuration
SERVICE_NAME="Save to Cortex"
SERVICE_PATH="$HOME/Library/Services/$SERVICE_NAME.workflow"
CONTENTS_PATH="$SERVICE_PATH/Contents"

echo "Creating Enhanced Service at $SERVICE_PATH..."

# Force remove old version to ensure clean install
rm -rf "$SERVICE_PATH"

# Create directory structure
mkdir -p "$CONTENTS_PATH"

# Generate UUIDs
UUID1=$(uuidgen)
UUID2=$(uuidgen)
UUID3=$(uuidgen)

# Create Info.plist
cat > "$CONTENTS_PATH/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleName</key>
	<string>${SERVICE_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>com.cortex.SaveToCortex</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>NSPrincipalClass</key>
	<string>AMWorkflowServiceApplication</string>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSBackgroundColorName</key>
			<string>background</string>
			<key>NSIconName</key>
			<string>NSActionTemplate</string>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>${SERVICE_NAME}</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSSendTypes</key>
			<array>
				<string>public.utf8-plain-text</string>
				<string>public.rtf</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF

# Create document.wflow using CDATA + Heredoc + ARGS input method
# FIXED: Added '-' to python command so it reads script from stdin while taking args
cat > "$CONTENTS_PATH/document.wflow" <<'WORKFLOW_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>CheckedForUserDefaultShell</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string><![CDATA[/usr/bin/python3 - "$@" <<'PY_END'
import sys, urllib.parse, subprocess, os, datetime
import traceback

log_file = '/tmp/cortex_capture.log'

def log(msg):
    try:
        with open(log_file, 'a') as f:
            ts = datetime.datetime.now().isoformat()
            f.write(f'{ts}: {msg}\n')
    except:
        pass

try:
    log('--- START CAPTURE (STABLE VER) ---')
    
    # Read text from ARGS instead of stdin
    # sys.argv[0] is "-", sys.argv[1...] are the inputs
    text = ""
    if len(sys.argv) > 1:
        text = " ".join(sys.argv[1:]).strip()
    
    # Fallback to stdin if args are empty (just in case)
    if not text:
        try:
            stdin_text = sys.stdin.read().strip()
            if stdin_text:
                text = stdin_text
                log('Debug: Fell back to stdin, found text')
        except:
            pass

    log(f'Text length: {len(text)}')
    
    source_url = ''
    source_type = 'article'
    
    # AppleScript to capture context
    # Double-escaped quotes (\\") to survive Python parsing
    applescript_cmd = '''
    tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
    end tell
    set sourceData to ""
    set debugLog to "App: " & frontApp & "; "
    
    try
        if frontApp contains "Chrome" or frontApp contains "Brave" or frontApp contains "Arc" then
            set sourceData to run script "tell application \\"" & frontApp & "\\" to get URL of active tab of front window"
        else if frontApp is "Safari" then
            set sourceData to run script "tell application \\"Safari\\" to get URL of front document"
        else if frontApp is "Preview" then
            set sourceData to run script "tell application \\"Preview\\" to get path of front document"
        else if frontApp is "Finder" then
             tell application "Finder"
                try
                    set theSelection to selection
                    if (count of theSelection) > 0 then
                        set theItem to item 1 of theSelection
                        set sourceData to POSIX path of (theItem as alias)
                    end if
                on error
                    set sourceData to ""
                end try
            end tell
        end if
    on error errMsg
        set debugLog to debugLog & "AS Error: " & errMsg
    end try

    return debugLog & sourceData
    '''
    
    try:
        # Run AppleScript to get URL/Path
        proc = subprocess.run(['osascript', '-e', applescript_cmd], 
                            capture_output=True, text=True, timeout=5)
        raw_output = proc.stdout.strip()
        log(f'AppleScript Raw: {raw_output}')
        
        if proc.stderr:
            log(f'AppleScript Stderr: {proc.stderr}')
        
        # Split debug log from actual data
        if '; ' in raw_output:
            parts = raw_output.split('; ')
            captured_data = parts[-1] 
        else:
            captured_data = raw_output 
            
        log(f'Captured Data: {captured_data}')
        
        # Handle File Paths from Finder/Preview
        if captured_data.startswith('file://') or captured_data.startswith('/'):
            source_url = captured_data
            source_type = 'document'
        elif captured_data.startswith('http'):
            source_url = captured_data
    except Exception as as_err:
        log(f'AppleScript Error: {as_err}')
    
    if text:
        encoded_text = urllib.parse.quote(text)
        encoded_url = urllib.parse.quote(source_url)
        
        url = f'cortex://capture?text={encoded_text}&type={source_type}&url={encoded_url}'
        log(f'Opening URL: {url}')
        
        subprocess.run(['open', '-a', 'cortex_app'], timeout=2) 
        subprocess.run(['open', url], timeout=2)
        log('SUCCESS: URL opened')
    else:
        log('ERROR: No text received')
        
except Exception as e:
    log(f'Fatal Error: {e}')
    log(traceback.format_exc())
PY_END
]]></string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/zsh</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>INPUT_UUID_PLACEHOLDER</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
					<string>Unix</string>
				</array>
				<key>OutputUUID</key>
				<string>OUTPUT_UUID_PLACEHOLDER</string>
				<key>UUID</key>
				<string>ACTION_UUID_PLACEHOLDER</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
				<key>arguments</key>
				<dict>
					<key>0</key>
					<dict>
						<key>default value</key>
						<integer>0</integer>
						<key>name</key>
						<string>inputMethod</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>0</string>
					</dict>
					<key>1</key>
					<dict>
						<key>default value</key>
						<false/>
						<key>name</key>
						<string>CheckedForUserDefaultShell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>1</string>
					</dict>
					<key>2</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>source</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>2</string>
					</dict>
					<key>3</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>COMMAND_STRING</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>3</string>
					</dict>
					<key>4</key>
					<dict>
						<key>default value</key>
						<string>/bin/sh</string>
						<key>name</key>
						<string>shell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>4</string>
					</dict>
				</dict>
				<key>isViewVisible</key>
				<true/>
				<key>location</key>
				<string>309.000000:305.000000</string>
				<key>nibPath</key>
				<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
			</dict>
			<key>isViewVisible</key>
			<true/>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>variables</key>
	<array/>
	<key>workflowMetaData</key>
	<dict>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.text</string>
		<key>serviceOutputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WORKFLOW_EOF

# Replace UUID placeholders
sed -i '' "s/INPUT_UUID_PLACEHOLDER/$UUID1/g" "$CONTENTS_PATH/document.wflow"
sed -i '' "s/OUTPUT_UUID_PLACEHOLDER/$UUID2/g" "$CONTENTS_PATH/document.wflow"
sed -i '' "s/ACTION_UUID_PLACEHOLDER/$UUID3/g" "$CONTENTS_PATH/document.wflow"

echo "✅ Service created successfully!"

# Flush service cache
echo "Flushing service cache..."
/System/Library/CoreServices/pbs -flush || true
killall pbs 2>/dev/null || true

echo "Done! Workflow automation moved to repository."
