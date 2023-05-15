chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === "getHighlightedTextAndURL") {
      console.log("BG request", request);
      console.log("BG sender", sender.tab);
      sendResponse({ highlightedText: request.text });
    }
  });
  