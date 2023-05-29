import 'package:flutter/material.dart';

Widget addVerticalSpace(int height) => SizedBox(height: height.toDouble());

String getYtThumbnail(String? url) {
  final uri = Uri.parse(url!);
  final videoId = uri.queryParameters["v"];
  return "https://img.youtube.com/vi/$videoId/sddefault.jpg";
}
