import subprocess
import sys

def run_script(name, script):
    print(f"--- Testing {name} ---")
    try:
        proc = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
        if proc.returncode == 0:
            print(f"SUCCESS: {proc.stdout.strip()}")
        else:
            print(f"ERROR: {proc.stderr.strip()}")
    except Exception as e:
        print(f"EXCEPTION: {e}")
    print("\n")

def debug_modules():
    # 1. Get Front App
    front_app_script = '''
    tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
    end tell
    return frontApp
    '''
    run_script("Get Front App", front_app_script)

    # 2. Chrome
    chrome_script = '''
    tell application "Google Chrome"
        if (count of windows) > 0 then
            return URL of active tab of front window
        else
            return "No windows"
        end if
    end tell
    '''
    run_script("Chrome Logic", chrome_script)

    # 3. Safari
    safari_script = '''
    tell application "Safari"
        if (count of documents) > 0 then
            return URL of front document
        else
            return "No documents"
        end if
    end tell
    '''
    run_script("Safari Logic", safari_script)
    
    # 4. Preview
    preview_script = '''
    tell application "Preview"
        if (count of documents) > 0 then
            return path of front document
        else
            return "No documents"
        end if
    end tell
    '''
    run_script("Preview Logic", preview_script)

    # 5. Finder
    finder_script = '''
    tell application "Finder"
        set theSelection to selection
        if (count of theSelection) > 0 then
            set theItem to item 1 of theSelection
            return POSIX path of (theItem as alias)
        else
            return "No selection"
        end if
    end tell
    '''
    run_script("Finder Logic", finder_script)

if __name__ == "__main__":
    debug_modules()
