export async function getActiveTab() {
    const tabs = await chrome.tabs.query({
        currentWindow: true,
        active: true
    });
  
    return tabs[0];
}

export async function getSelectedText(tab) {
    console.log('getSelectedText', tab);
    const [{selection}] = await chrome.scripting.executeScript({
        target: {tabId: tab.id},
        function: () => {
            console.log('window.getSelection()');
            window.getSelection().toString()
        },
    });
    return selection;
}