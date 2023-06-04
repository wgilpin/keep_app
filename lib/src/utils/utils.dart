import 'package:flutter/material.dart';

Widget addVerticalSpace(int height) => SizedBox(height: height.toDouble());

String? getYtThumbnail(String? url) {
  if (url == null) return null;
  final uri = Uri.parse(url);
  final videoId = uri.queryParameters["v"];
  return "https://img.youtube.com/vi/$videoId/sddefault.jpg";
}

String makeShareURL(String noteId) {
  return "${Uri.base.origin}/#/share?id=$noteId";
}
