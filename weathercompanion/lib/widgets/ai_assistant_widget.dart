// lib/widgets/ai_assistant_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'dart:async';

class AiAssistantWidget extends StatefulWidget {
  final String cityName;
  final double temperature;
  final String weatherDescription;
  final List<dynamic> forecastDays;
  final bool isLoading;

  const AiAssistantWidget({
    super.key,
    required this.cityName,
    required this.temperature,
    required this.weatherDescription,
    required this.forecastDays,
    required this.isLoading,
  });

  @override
  State<AiAssistantWidget> createState() => _AiAssistantWidgetState();
}

class _AiAssistantWidgetState extends State<AiAssistantWidget> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Gemini _gemini = Gemini.instance;
  final FocusNode _focusNode = FocusNode();

  bool _isChatLoading = false;
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _chatHistory.add({
      'role': 'model',
      'text':
          'Hi! I’m Mr. WFC, your friendly Weather Companion. Curious about today’s weather? Need a forecast? Or just want someone to talk to? I’m here for you!', // Updated greeting
    });
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Use Scrollable.ensureVisible with the widget's context
          // This requires finding the nearest Scrollable ancestor
          Scrollable.of(context).position.ensureVisible(
            context.findRenderObject()!, // Use the widget's RenderObject
            alignment: 0.1, // Align near the top after scrolling
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    if (_chatController.text.isEmpty) return;

    final String userMessage = _chatController.text;
    _chatController.clear();
    _focusNode.unfocus();

    setState(() {
      _isChatLoading = true;
      _chatHistory.add({'role': 'user', 'text': userMessage});
      _scrollToBottom();
    });

    // 1. Check if we have real data from the home screen
    final bool hasRealData =
        !widget.isLoading && widget.forecastDays.isNotEmpty;

    // 2. Build a context-aware prompt
    String contextPrompt;
    if (hasRealData) {
      // Create a clean summary of the forecast
      final forecastSummary = widget.forecastDays
          .map((day) {
            final dayData = day['day'] ?? {};
            final date = day['date'] ?? 'N/A';
            final minTemp = (dayData['mintemp_c'] as num?)?.round() ?? '?';
            final maxTemp = (dayData['maxtemp_c'] as num?)?.round() ?? '?';
            final condition = dayData['condition']?['text'] ?? 'N/A';
            return "Date: $date, Min: ${minTemp}°C, Max: ${maxTemp}°C, Condition: $condition";
          })
          .join("\n");

      contextPrompt =
          """
      You are Mr. WFC, a helpful and friendly AI weather assistant represented by a cute cloud character.
      Use the following **current weather data** to answer my question conversationally and cheerfully.
      Address me as "Companion" at least once.

      CURRENT DATA:
      - Location: ${widget.cityName}
      - Temperature: ${widget.temperature.round()}°C
      - Condition: ${widget.weatherDescription}
      - 7-Day Forecast: \n$forecastSummary

      Based on that data, please answer my question:
      """;
    } else {
      // Fallback if data isn't loaded yet
      contextPrompt = """
      You are Mr. WFC, a helpful and friendly AI weather assistant represented by a cute cloud character.
      My weather data isn't loaded yet, so just answer this general question cheerfully:
      """;
    }

    // 3. Create the final list of messages
    final List<Content> chatMessages = [
      // This combines the context and the user's question
      Content(
        parts: [Part.text("$contextPrompt\n\n$userMessage")],
        role: 'user',
      ),
    ];

    // Send to Gemini
    _gemini
        .chat(
          chatMessages, // Pass the new, context-rich messages
          modelName: 'gemini-pro',
        )
        .then((response) {
          final String? modelResponse = response?.output;
          if (mounted) {
            setState(() {
              _isChatLoading = false;
              _chatHistory.add({
                'role': 'model',
                'text':
                    modelResponse ??
                    "Hmm, my circuits are a bit cloudy right now. Could you ask that again?", // Themed error
              });
              _scrollToBottom();
            });
          }
        })
        .catchError((e) {
          if (mounted) {
            setState(() {
              _isChatLoading = false;
              _chatHistory.add({
                'role': 'model',
                'text':
                    'Uh oh! A little storm in my system: ${e.toString()}', // Themed error
              });
              _scrollToBottom();
            });
          }
        });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ), // Added subtle border
      ),
      child: Column(
        children: [
          // Chat history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final message = _chatHistory[index];
                final bool isUser = message['role'] == 'user';

                //
                // ✅ --- THIS IS THE VISUAL CHANGE --- ✅
                //
                if (isUser) {
                  // User message aligns right
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(
                        top: 4,
                        bottom: 4,
                        left: 60,
                      ), // Margin to prevent overlap
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7986CB), // User bubble color
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        message['text']!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                } else {
                  // AI message aligns left, includes mascot
                  return Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                      bottom: 4,
                      right: 40,
                    ), // Margin to prevent overlap
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start, // Align mascot to top
                      children: [
                        // The Mascot Image
                        CircleAvatar(
                          backgroundImage: const AssetImage(
                            'assets/images/logo.png',
                          ),
                          radius: 18, // Adjust size as needed
                          backgroundColor: Colors
                              .transparent, // Avoid white background if PNG has transparency
                        ),
                        const SizedBox(
                          width: 8,
                        ), // Space between mascot and bubble
                        // The Chat Bubble (use Flexible for wrapping)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                0.9,
                              ), // AI bubble color
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              message['text']!,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                //
                // ✅ --- END OF VISUAL CHANGE --- ✅
                //
              },
            ),
          ),

          if (_isChatLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                color: Colors.white,
                backgroundColor: Colors.transparent,
                minHeight: 2, // Make it subtle
              ),
            ),

          // Input row
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ask Mr. WFC...", // Updated hint
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ), // Adjust padding
                      isDense: true,
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                  tooltip: 'Send message', // Accessibility
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
