// lib/widgets/ai_assistant_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
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
  // ✅ Using gemini-pro, compatible with v1beta used by flutter_gemini 3.0.0
  // Model name can be adjusted if needed, but 'gemini-pro' is a common default.
  // If you were using 'gemini-flash-latest' before, you can keep that:
  // final String _modelName = 'gemini-flash-latest';
  final String _modelName = 'gemini-pro'; // Or 'gemini-flash-latest' if preferred


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
        "Current weather in ${widget.cityName}: ${widget.temperature.round()}°C and ${widget.weatherDescription}."; // Used round() for cleaner temp

    // Add 7-day forecast summary if available
    if (widget.forecastDays.isNotEmpty) {
      context += "\n\nAvailable Forecast Summary:\n"; // Changed title slightly
      // Limit to max 7 days for brevity
      final daysToShow = widget.forecastDays.length > 7
          ? widget.forecastDays.sublist(0, 7)
          : widget.forecastDays;
      for (var dayData in daysToShow) {
        final day = dayData['day'] ?? {};
        final date = dayData['date'] ?? 'Unknown Date';
        final condition = day['condition']?['text'] ?? 'No condition';
        final maxTemp = (day['maxtemp_c'] as num?)?.round() ?? 'N/A';
        final minTemp = (day['mintemp_c'] as num?)?.round() ?? 'N/A';
        context +=
            "- $date: $condition, High: $maxTemp°C / Low: $minTemp°C\n"; // Added High/Low labels
      }
    } else {
       context += "\n\nNo forecast data is currently available.";
    }
    // Added instruction for AI
    return "You are a helpful weather assistant named Mr. WFC. Answer the user's question concisely based *only* on the following weather context. Do not mention 'context' or 'data provided'. If the context doesn't contain the answer, say you don't have that specific information right now.\n\nContext:\n$context";
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isAILoading) return; // Added trim()

    final userMessage = _controller.text.trim();
    _controller.clear();

    setState(() {
      _chatHistory.add({'isUser': true, 'message': userMessage});
      _isAILoading = true;
    });
    _scrollToBottom();

    final contextPrompt = _generateContextPrompt();
    final fullPrompt = "$contextPrompt\n\nUser Question: $userMessage";
    developer.log("Sending AI Assistant prompt:\n$fullPrompt", name: "AiAssistantWidget");

    try {
      // 🚀 *** FIX: Switched from gemini.chat() to gemini.text() ***
      final response = await gemini.text(
        fullPrompt,
        // modelName: _modelName, // modelName is optional for .text(), defaults likely used
      );

      // 🚀 *** FIX: Access output differently for .text() ***
      // Use .output or iterate through candidates if needed
      final aiResponse = response?.output ?? "Sorry, I couldn't understand that.";
      developer.log("AI Assistant response: $aiResponse", name: "AiAssistantWidget");


      setState(() {
        _chatHistory.add({'isUser': false, 'message': aiResponse});
        _isAILoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      developer.log('AI Assistant Error: $e', name: 'AiAssistantWidget', error: e);
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
                final bool isUser = chat['isUser'] ?? false; // Added null check
                final message = chat['message'] ?? ''; // Added null check
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment:
                        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start, // Align top
                    children: [
                      if (!isUser)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0, top: 5.0), // Align icon better
                          child: Image.asset('assets/images/logo.png',
                              width: 24, height: 24),
                        ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF3F51B5).withOpacity(0.8) // Slightly transparent user bubble
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12), // Slightly more rounded
                          ),
                          child: Text(
                            message,
                            style: const TextStyle(color: Colors.white, fontSize: 15), // Slightly larger text
                          ),
                        ),
                      ),
                       if (isUser) // Add padding for user bubble alignment
                         const SizedBox(width: 32),
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
                    hintText: "Ask about the weather...", // More specific hint
                    hintStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 10), // Adjusted padding
                    isDense: true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send, // Use send action
                ),
              ),
              const SizedBox(width: 8),
              _isAILoading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0), // Match button size better
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5)), // Slightly thicker stroke
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      iconSize: 24, // Explicit size
                      tooltip: "Send message",
                      onPressed: _sendMessage,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}