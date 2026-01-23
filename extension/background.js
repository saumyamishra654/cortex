// Cortex Capture - Chrome Extension Background Script

// Create context menu on install
chrome.runtime.onInstalled.addListener(() => {
    chrome.contextMenus.create({
        id: "cortex-capture",
        title: "Save to Cortex",
        contexts: ["selection"]
    });
    console.log("Cortex Capture: Context menu created");
});

// Handle context menu click
chrome.contextMenus.onClicked.addListener((info, tab) => {
    if (info.menuItemId !== "cortex-capture") return;

    const selectedText = info.selectionText || "";
    if (!selectedText.trim()) {
        console.log("Cortex Capture: No text selected");
        return;
    }

    // URL encode the parameters
    const text = encodeURIComponent(selectedText);
    const pageUrl = encodeURIComponent(tab.url || "");
    const pageTitle = encodeURIComponent(tab.title || "");

    // Detect source type from URL
    let sourceType = "article";
    const url = tab.url?.toLowerCase() || "";
    if (url.includes("youtube.com") || url.includes("vimeo.com")) {
        sourceType = "video";
    } else if (url.includes("twitter.com") || url.includes("x.com") || url.includes("instagram.com")) {
        sourceType = "social_post";
    } else if (url.includes("spotify.com") || url.includes("podcasts.apple.com")) {
        sourceType = "podcast";
    } else if (url.includes("tiktok.com") || url.includes("shorts")) {
        sourceType = "reels";
    }

    // Build deep link URL
    const cortexUrl = `cortex://capture?text=${text}&url=${pageUrl}&title=${pageTitle}&type=${sourceType}`;

    console.log("Cortex Capture: Opening deep link", cortexUrl);

    // Open the deep link (will launch the Cortex app)
    chrome.tabs.create({ url: cortexUrl });
});
