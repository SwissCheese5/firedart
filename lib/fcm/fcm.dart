import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../base/firebase.dart';
import 'message.dart';

/// FCM Option defined here: https://firebase.google.com/docs/cloud-messaging/send-message#rest
/// Don't know why you should overwrite these settings but you can.
class FCMConfig {
  static const scheme = 'https';
  static const host = 'fcm.googleapis.com';
  static const method = 'POST';
  static const bool keepAlive = false;
  final headers = <String,String>{};
  String project_id;

  FCMConfig(this.project_id);

  String get path => '/v1/projects/$project_id/messages:send';
}

class FCM {
  /* Singleton instance */
  static FCM _instance;

  static bool get initialized => _instance != null;

  static FCM initialize(
      {Firebase firebase, FCMConfig fcmConfig}) {
    assert(!initialized,
    'Firestore global instance is already initialized. Do not call this twice or create a local instance via FCM()');

    _instance = FCM(
        firebase: firebase ?? Firebase.instance, fcmConfig: fcmConfig);
    return _instance;
  }

  static FCM get instance {
    assert(initialized,
    "Firestore hasn't been initialized. Call Firestore.initialize() before using this global instance. Alternatively, create a local instance via Firestore() and use that.");

    return _instance;
  }

  /* Instance interface */
  final Firebase firebase;
  final FCMConfig fcmConfig;

  FCM({@required this.firebase, @required this.fcmConfig})
      : assert(firebase != null || Firebase.initialized,
  'Firebase global instance not initialized, run Firebase.initialize().\nAlternatively, provide a local instance via Firestore.initialize(firebase: <firebase instance>)'),
        assert(fcmConfig != null, 'Firebase Cloud Messaging configuration is missing.');

  /// https://firebase.google.com/docs/cloud-messaging/send-message#send-messages-to-specific-devices
  ///
  /// Throws a V1FcmError if the requests fails or server replies an error.
  ///
  /// Returns ID string in format projects/{project_id}/messages/{message_id}
  /// if the request is successful.
  /// Example: "projects/myproject-b5ae1/messages/0:1500415314455276%31bd1c9631bd1c96"
  Future<String> send(V1Message message) async {
    var request = http.Request(FCMConfig.method, Uri(
      scheme: FCMConfig.scheme,
      host: FCMConfig.host,
      path: fcmConfig.path,
    ));
    request.body = json.encode({'message': message.toJson()});;
    
    var response = await firebase.client.send(request);
    var responseContent = await response.stream.bytesToString();
    if (response.statusCode >= 400) {
      throw V1FcmError(responseContent);
    }

    var responseMessage = V1Response.fromJson(json.decode(responseContent));
    return responseMessage.name;
  }
}
