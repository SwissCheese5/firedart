import 'dart:convert';

import 'package:firedart/auth/token_provider.dart';
import 'package:http/http.dart' as http;

class VerboseClient extends http.BaseClient {
  http.Client _client;

  VerboseClient() {
    _client = http.Client();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    print("--> ${request.method} ${request.url}");
    print(request.headers);
    print((request as http.Request).body);

    var response = await _client.send(request);
    print(
        "<-- ${response.statusCode} ${response.reasonPhrase} ${response.request.url}");
    var loggedStream = response.stream.map((event) {
      print(utf8.decode(event));
      return event;
    });

    return http.StreamedResponse(
      loggedStream,
      response.statusCode,
      headers: response.headers,
      contentLength: response.contentLength,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
      request: response.request,
    );
  }
}

class KeyClient extends http.BaseClient {
  final http.Client client;
  final String apiKey;

  KeyClient(this.client, this.apiKey);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!request.url.queryParameters.containsKey("key")) {
      var query = Map<String, String>.from(request.url.queryParameters)
        ..["key"] = apiKey;
      var url = Uri.https(request.url.authority, request.url.path, query);
      request = http.Request(request.method, url)
        ..headers.addAll(request.headers)
        ..bodyBytes = (request as http.Request).bodyBytes;
    }
    return client.send(request);
  }
}

class UserClient extends http.BaseClient {
  final KeyClient client;
  final TokenProvider tokenProvider;

  UserClient(this.client, this.tokenProvider);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var response = await client.send(await _signRequest(request));
    if (response.statusCode == 400) {
      tokenProvider.invalidateToken();
      response = await client.send(await _signRequest(request));
    }
    return response;
  }

  Future<http.BaseRequest> _signRequest(http.BaseRequest request) async {
    return http.Request(request.method, request.url)
      ..headers["content-type"] = "application/x-www-form-urlencoded"
      ..bodyFields = {"idToken": await tokenProvider.idToken};
  }
}

class AuthClient extends http.BaseClient {
  final http.Client client;
  final TokenProvider tokenProvider;

  AuthClient(this.client, this.tokenProvider);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var response = await client.send(await _signRequest(request));
    if (response.statusCode == 401 && tokenProvider != null) {
      tokenProvider.invalidateToken();
      // Copy request
      request = http.Request(request.method, request.url)
        ..body = (request as http.Request).body;
      response = await client.send(await _signRequest(request));
    }
    return response;
  }

  Future<http.BaseRequest> _signRequest(http.BaseRequest request) async {
    if (tokenProvider != null) {
      request.headers["Authorization"] =
          "Bearer ${await tokenProvider.idToken}";
    }
    return request;
  }
}