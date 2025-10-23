// lib/widgets/ai_assistant_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart'; // ✅ THE FIX IS THIS IMPORT
import 'dart:developer' as developer;

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
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final gemini = Gemini.instance;
  final List<Map<String, dynamic>> _chatHistory = [];
  bool _isAILoading = false;

  @override
  void initState() {
    super.initState();
    _chatHistory.add({
      'isUser': false,
      'message':
          "Hi! I'm Mr. WFC. Ask me anything about the current weather or forecast!",
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

  String _generateContextPrompt() {
    if (widget.isLoading) {
      return "The app is still loading weather data. Please let the user know you can't provide specifics yet.";
    }

    // Basic current conditions
    String context =
        "Current weather in ${widget.cityName}: ${widget.temperature}°C and ${widget.weatherDescription}.";

    // Add 7-day forecast summary if available
    if (widget.forecastDays.isNotEmpty) {
      context += "\n\n7-Day Forecast Summary:\n";
      for (var dayData in widget.forecastDays) {
        final day = dayData['day'] ?? {};
        final date = dayData['date'] ?? 'Unknown Date';
        final condition = day['condition']?['text'] ?? 'No condition';
        final maxTemp = (day['maxtemp_c'] as num?)?.round() ?? 'N/A';
        final minTemp = (day['mintemp_c'] as num?)?.round() ?? 'N/A';
        context +=
            "- $date: $condition, $maxTemp°C / $minTemp°C\n";
      }
    }
    return "Use the following weather data as context for your answer:\n$context";
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || _isAILoading) return;

    final userMessage = _controller.text;
    _controller.clear();

    setState(() {
      _chatHistory.add({'isUser': true, 'message': userMessage});
      _isAILoading = true;
    });
    _scrollToBottom();

    final contextPrompt = _generateContextPrompt();

    try {
      final response = await gemini.chat(
        [Content(parts: [Part.text("$contextPrompt\n\nUser Question: $userMessage")], role: 'user')],
      );

      final aiResponse = response?.output ?? "Sorry, I couldn't understand that.";

      setState(() {
        _chatHistory.add({'isUser': false, 'message': aiResponse});
        _isAILoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      developer.log('AI Chat Error: $e', name: 'AiAssistantWidget');
      setState(() {
        _chatHistory.add({
          'isUser': false,
          'message': "Sorry, something went wrong. Please try again."
        });
        _isAILoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ask Mr. WFC (AI Assistant)",
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            height: 200, // Fixed height for chat history
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final chat = _chatHistory[index];
                final bool isUser = chat['isUser'];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment:
                        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isUser)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Image.asset('assets/images/logo.png',
                              width: 24, height: 24),
                        ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF3F51B5)
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            chat['message'],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Type your message...",
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              _isAILoading
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child:
                          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}