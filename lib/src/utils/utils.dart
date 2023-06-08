import 'package:flutter/material.dart';

// add "height" pixels of vertical space, for use in columns
Widget addVerticalSpace(int height) => SizedBox(height: height.toDouble());

// get the youtube thumbnail given a youtube URL
String? getYtThumbnail(String? url) {
  if (url == null) return null;
  // the thumbnail has the same id as the video
  final uri = Uri.parse(url);
  // the video id is the query parameter "v"
  final videoId = uri.queryParameters["v"];
  if (videoId == null) return null;
  return "https://img.youtube.com/vi/$videoId/sddefault.jpg";
}

// make a URL to share a note given a note ID
String makeShareURL(String noteId) {
  return "${Uri.base.origin}/#/share?id=$noteId";
}
