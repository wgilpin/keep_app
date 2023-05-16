console.log("popup.js loaded");
import { getActiveTab } from "./utils.js";

// Get URL & selection
let activeTab = await getActiveTab();
console.log("url", activeTab.url);
let url = activeTab.url;
let title = activeTab.title;
let selectedText = null;

// get current selected text from the content script
await chrome.tabs.sendMessage(
  activeTab.id,
  { message: "getSelection" },
  function (response) {
    selectedText = response?.selection;
    setIframeUrl(url, selectedText, title);
  }
);

// listen for a message from the iframe, to close the window
window.addEventListener('message', function(event) {
  if (event.data == "closePopup"){
    window.close();
  }
});

document.addEventListener('message', function(event) {
  if (event.data == "closePopup"){
    window.close();
  }
});

function setIframeUrl(url, selectedText, title) {
  // add comment to the iframe url as a query param
  let keepIFrame = document.getElementById("iframe");
  let params = {
    url: url,
    snippet: selectedText,
    title: title,
  };

  let iframe_src = "http://localhost:52233/#/iframe?";
  Object.entries(params).forEach(([k, v]) => {
    if (v != null) {
      iframe_src += `${k}=${encodeURIComponent(v)}&`;
    }
  });
  keepIFrame.src = iframe_src;
}

