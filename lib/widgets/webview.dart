import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http; // Import for making HTTP requests

class IdentityKYCWebView extends StatefulWidget {
  final String merchantKey;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? userRef;
  final String config;
  final Function onCancel;
  final Function onVerified;
  final Function onError;

  IdentityKYCWebView({
    required this.merchantKey,
    required this.email,
    required this.config,
    this.firstName,
    this.lastName,
    this.userRef,
    required this.onCancel,
    required this.onVerified,
    required this.onError,
  });

  @override
  _IdentityKYCWebViewState createState() => _IdentityKYCWebViewState();
}

class _IdentityKYCWebViewState extends State<IdentityKYCWebView> {
  InAppWebViewController? _webViewController; // Make it nullable
  String? _webViewUrl; // To store the dynamically generated URL
  bool _isLoading = true; // To show loader
  String? _errorMessage; // To show error messages if API call fails

  DateTime? _lastEventTime;
  Duration debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _initializePremblyWidget();
  }

  Future<void> _initializePremblyWidget() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    final String apiUrl = 'https://api.prembly.com/identitypass/internal/checker/sdk/widget/initialize';

    // Prepare the request body
    final Map<String, dynamic> requestBody = {
      "first_name": widget.firstName ?? "", // Use null-aware operator
      "public_key": widget.merchantKey, // Your merchantKey is the public_key
      "last_name": widget.lastName ?? "", // Use null-aware operator
      "email": widget.email,
      "user_ref": widget.userRef ?? "", // Use null-aware operator
      "config_id": widget.config,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'accept': '*/*', 'accept-language': 'en-GB,en-US;q=0.9,en;q=0.8', 'content-type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == true && responseData.containsKey('widget_id')) {
          final String widgetId = responseData['widget_id'];
          setState(() {
            _webViewUrl = "https://dev.d1gc80n5odr0sp.amplifyapp.com/$widgetId";
            _isLoading = false;
          });
        } else {
          // API call successful but response indicates an error or missing widget_id
          setState(() {
            _errorMessage = responseData['detail'] ?? 'Failed to get widget ID from API.';
            _isLoading = false;
          });
          widget.onError({"status": "api_error", "message": _errorMessage});
        }
      } else {
        // API call failed with a non-200 status code
        setState(() {
          _errorMessage = 'API call failed with status: ${response.statusCode}. Response: ${response.body}';
          _isLoading = false;
        });
        widget.onError({"status": "api_error", "message": _errorMessage});
      }
    } catch (e) {
      // Network error or JSON decoding error
      setState(() {
        _errorMessage = 'Network error or data parsing error: $e';
        _isLoading = false;
      });
      widget.onError({"status": "network_error", "message": _errorMessage});
    }
  }

  void _handleWebViewEvent(VoidCallback callback) {
    DateTime now = DateTime.now();
    if (_lastEventTime == null || now.difference(_lastEventTime!) > debounceDuration) {
      _lastEventTime = now;
      callback();
    } else {
      debugPrint("Ignored duplicate event");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: GlobalKey<NavigatorState> is not needed here as we are not pushing/popping routes
    // within this widget's Navigator. The MaterialPageRoute handles it.

    return PopScope(
      canPop: false, // Prevents popping the route
      child: Material(
        type: MaterialType.transparency,
        child: Builder(
          builder: (_) {
            if (_isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Initializing secure session..."),
                  ],
                ),
              );
            }

            if (_errorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 16),
                      Text(
                        "Error: $_errorMessage",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _initializePremblyWidget,
                        child: const Text("Retry"),
                      ),
                      TextButton(
                        onPressed: () => widget.onCancel({"status": "error_display_closed"}),
                        child: const Text("Cancel"),
                      ),
                    ],
                  ),
                ),
              );
            }

            return InAppWebView(
              onPermissionRequest: (controller, request) async {
                // Log the requested resources for debugging.
                debugPrint("WebView permission request for: ${request.resources}");

                // Determine if the request is for camera or microphone.
                // The web page can request these individually or, on iOS, as a combined type.
                bool wantsCamera = request.resources.any((res) => res == PermissionResourceType.CAMERA);
                bool wantsMicrophone = request.resources.any((res) => res == PermissionResourceType.MICROPHONE);
                bool wantsCameraAndMicrophoneIOS =
                    request.resources.any((res) => res == PermissionResourceType.CAMERA_AND_MICROPHONE);

                if (wantsCamera || wantsMicrophone || wantsCameraAndMicrophoneIOS) {
                  // If camera or microphone permissions are requested, grant them.
                  // It's crucial to pass back the original `request.resources` list.
                  debugPrint("Granting permissions for: ${request.resources}");
                  return PermissionResponse(
                    resources: request.resources, // Use the resources from the original request.
                    action: PermissionResponseAction.GRANT,
                  );
                }

                // For any other types of permission requests, deny them.
                debugPrint("Denying permissions for: ${request.resources}");
                return PermissionResponse(
                  resources: request.resources, // Use the resources from the original request.
                  action: PermissionResponseAction.DENY,
                );
              },
              initialUrlRequest: URLRequest(
                url: WebUri(_webViewUrl!), // Use the generated URL
              ),
              initialSettings: InAppWebViewSettings(
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
              ),
              onWebViewCreated: (InAppWebViewController controller) {
                _webViewController = controller;
                _webViewController!.addJavaScriptHandler(
                  // Use nullable accessor
                  handlerName: 'message',
                  callback: (args) {
                    _handleWebViewEvent(() {
                      try {
                        // Ensure args is not empty and the first element is a String
                        if (args.isNotEmpty && args[0] is String) {
                          Map response = json.decode(args[0]);
                          if (response.containsKey("event")) {
                            switch (response["event"]) {
                              case "closed":
                                widget.onCancel({"status": "closed"});
                                break;
                              case "error":
                                widget.onError({
                                  "status": "error",
                                  "message": response['message'],
                                });
                                break;
                              case "verified":
                                widget.onVerified({
                                  "status": "success",
                                  "data": response,
                                });
                                break;
                              default:
                                // Handle unknown events gracefully
                                debugPrint("Received unknown event from WebView: ${response['event']}");
                                break;
                            }
                          }
                        } else if (args.isNotEmpty && args[0] is Map) {
                          Map response = args[0];
                          if (response.containsKey("data")) {
                            Map data = response["data"];
                            if (data.containsKey("status")) {
                              switch (data["status"]) {
                                case "failed":
                                  if (("${data["message"] ?? ''}".toLowerCase().contains('cancel'))) {
                                    widget.onCancel({
                                      "status": "cancelled",
                                      "message": data["message"],
                                    });
                                    break;
                                  }
                                  widget.onError({
                                    "status": "failed",
                                    "message": data['message'],
                                  });
                                  break;
                                case "success":
                                  widget.onVerified({
                                    "status": "success",
                                    "data": data,
                                  });
                                  break;
                                default:
                                  // Handle unknown events gracefully
                                  widget.onError({
                                    "status": data["status"],
                                    "message": data['message'],
                                  });
                                  break;
                              }
                            }
                          }
                        } else {
                          // Handle cases where args[0] is not a String or args is empty
                          debugPrint("Received non-string data from JavaScript handler: ${args}");
                          // Optionally, call onError or log a specific message for this case
                          widget.onError({
                            "status": "error",
                            "message": "Received unexpected data type from WebView: $args",
                          });
                        }
                      } catch (e) {
                        debugPrint("Error decoding JSON from WebView: $e");
                        // Log the raw args[0] for debugging
                        if (args.isNotEmpty) {
                          debugPrint("Raw data from WebView: ${args[0]}");
                        }
                        widget.onError(
                          {
                            "status": "error",
                            "message": "Failed to process message from WebView: $e",
                          },
                        );
                      }
                    });
                  },
                );
              },
              onConsoleMessage: (
                InAppWebViewController controller,
                ConsoleMessage consoleMessage,
              ) {
                debugPrint("WEB CONSOLE: ${consoleMessage.message}");
                debugPrint("WEB CONSOLE SOURCE ID: ${consoleMessage.messageLevel}");
              },
              onLoadStop: (controller, url) async {
                //This Javascript is for updating the background color
                await controller.evaluateJavascript(source: """
                  var style = document.createElement('style');
                  style.innerHTML = ".main-modal { background-color: rgba(255, 255, 255) !important; }";
                  document.head.appendChild(style);
                """);

                //This Javascript is used to disable the auto-zoom when input is focused
                await controller.evaluateJavascript(source: """
                  var meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
                  document.getElementsByTagName('head')[0].appendChild(meta);
                """);

                // This JavaScript is for the web page to send messages back to Flutter.
                // It does NOT initiate camera access. The web page itself must do that.
                await controller.evaluateJavascript(
                  source: """
                          window.addEventListener("message", (event) => {
                            window.flutter_inappwebview
                                .callHandler('message', event.data);
                          }, false);
                        """,
                );

                // Optional: Add a check for camera access from the web page for debugging
                // This is just a test to see if the browser API works, not to start the camera itself
                await controller.evaluateJavascript(
                  source: """
                          navigator.mediaDevices.getUserMedia({ video: true, audio: true })
                            .then(function(stream) {
                              console.log('Camera and microphone access granted to web content!');
                              stream.getTracks().forEach(track => track.stop()); // Stop tracks immediately after testing
                            })
                            .catch(function(err) {
                              console.error('Error accessing camera/microphone in web content via getUserMedia test: ' + err.name + ': ' + err.message);
                            });
                        """,
                );
              },
              // Removed gestureRecognizers as it's typically not needed and can cause issues
            );
          },
        ),
      ),
    );
  }
}
