// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

Object platformPluginMethod() {
  // for the chrome extension, send a message to close the popup
  try {
    window.postMessage("closePopup", "*");

    IFrameElement element = document.getElementById('iframe') as IFrameElement;
    element.contentWindow?.postMessage("closePopup", '*');
    return Object();
  } catch (e) {
    return Object();
  }
}

Object platformPluginAlert(String message) {
  // for the chrome extension, send a message to close the popup
  try {
    window.alert(message);

    return Object();
  } catch (e) {
    return Object();
  }
}
