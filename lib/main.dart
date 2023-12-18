import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyWebView(),
    );
  }
}

class MyWebView extends StatefulWidget {
  @override
  _MyWebViewState createState() => _MyWebViewState();
}

class _MyWebViewState extends State<MyWebView> {
  final Completer<WebViewController> _controller = Completer<WebViewController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Data Display'),
      ),
      body: WebView(
        initialUrl: 'https://nadeer12.github.io/flutter_3api/',
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController controller) {
          _controller.complete(controller);
        },
        javascriptChannels: <JavascriptChannel>[
          _apiDataChannel(context, 'currency'),
          _apiDataChannel(context, 'user'),
          _apiDataChannel(context, 'item'),
        ].toSet(),
      ),
    );
  }

  // Function to create JavascriptChannel for API data communication
  JavascriptChannel _apiDataChannel(BuildContext context, String apiType) {
    return JavascriptChannel(
      name: 'ApiData_$apiType',
      onMessageReceived: (JavascriptMessage message) {
        print('Message received for $apiType: ${message.message}');
        _getApiData(message.message, apiType);
      },
    );
  }

  // Function to initiate API data retrieval and handle responses
  Future<void> _getApiData(String apiUrl, String apiType) async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Accessing WebViewController to execute Javascript in WebView
        _controller.future.then((controller) async {
          final jsonData = jsonEncode(data);
          controller.evaluateJavascript('displayApiData($jsonData, "$apiType")');

          if (apiType == 'currency' && data is List && data.isNotEmpty) {
            final firstData = data[0];

            // Making a second API request based on the first API response
            try {
              final response2 = await http.get(
                Uri.parse('http://eademoapi.linkwayapps.com/api/currency/getcurrency?currencysymbol=' + firstData),
              );

              if (response2.statusCode == 200) {
                final data2 = jsonDecode(response2.body);
                _showData2Dialog(data2);

                // Passing data2 variable back to index.html
                controller.evaluateJavascript('displayData2Alert(${jsonEncode(data2)})');
              } else {
                print('Error in second request: ${response2.statusCode}');
                // Handle error for the second request
              }
            } catch (error) {
              print('Error in second request: $error');
              // Handle error for the second request
            }
          }
        });
        await Future.delayed(Duration(seconds: 2));
      } else {
        print('Error for $apiType: ${response.statusCode}');
        _handleApiError();
      }
    } catch (error) {
      print('Error fetching data from $apiUrl for $apiType: $error');
      _handleApiError();
    }
  }

  // Function to show a dialog with additional details (data2)
  void _showData2Dialog(dynamic data2) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Currency First data Details'),
          content: Text(': $data2'),
          // You can customize the content of the dialog based on your data2 structure
        );
      },
    );
  }

  // Function to handle API errors
  Future<void> _handleApiError() async {
    _controller.future.then((controller) {
      controller.evaluateJavascript('displayApiError(\'Error fetching data.\')');
    });
  }
}
