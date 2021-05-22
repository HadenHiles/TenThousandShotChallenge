import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';

String constructFCMPayload(String token, String title, String body) {
  return jsonEncode({
    'token': token,
    'data': {
      'via': 'Firebase Cloud Messaging',
      'count': UniqueKey().toString(),
    },
    'notification': {
      'title': title,
      'body': body,
    },
  });
}

Future<void> sendPushMessage(String token, String title, String body) async {
  try {
    await http.post(
      Uri.parse('https://api.rnfirebase.io/messaging/send'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: constructFCMPayload(token, title, body),
    );
    print('FCM request for device sent!');
  } catch (e) {
    print(e);
  }
}
