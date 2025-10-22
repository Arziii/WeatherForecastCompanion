// lib/widgets/ai_assistant_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'dart:async';

class AiAssistantWidget extends StatefulWidget {
  // ✅ ADD: New variables to receive data
  final String cityName;
  final double temperature;
  final String weatherDescription;
  final List<dynamic> forecastDays;
  final bool isLoading;

  const AiAssistantWidget({
    super.key,
    // ✅ ADD: Make them required
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

  bool _isChatLoading = false; // Renamed to avoid confusion
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _chatHistory.add({
      'role': 'model',
      'text':
          'Hello! I am your AI Assistant. Ask me anything about the weather!',
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
          Scrollable.of(context).position.ensureVisible(
                context.findRenderObject()!,
                alignment: 0.1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
        }
      });
    }
  }

  //
  // ✅ --- THIS IS THE MAIN UPGRADE --- ✅
  //
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
    final bool hasRealData = !widget.isLoading && widget.forecastDays.isNotEmpty;
    
    // 2. Build a context-aware prompt
    String contextPrompt;
    if (hasRealData) {
      // Create a clean summary of the forecast
      final forecastSummary = widget.forecastDays.map((day) {
        return "Date: ${day['date']}, Min: ${day['day']['mintemp_c']}°C, Max: ${day['day']['maxtemp_c']}°C, Condition: ${day['day']['condition']['text']}";
      }).join("\n");

      contextPrompt = """
      You are a helpful AI weather assistant. 
      Use the following **current weather data** to answer my question.

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
      You are a helpful AI assistant. 
      I don't have my weather data loaded yet, so just answer this general question:
      """;
    }

    // 3. Create the final list of messages
    final List<Content> chatMessages = [
      // This combines the context and the user's question
      Content(
        parts: [Part.text("$contextPrompt\n\n$userMessage")], 
        role: 'user'
      )
    ];

    // Send to Gemini
    _gemini
        .chat(
      chatMessages, // ✅ Pass the new, context-rich messages
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
                modelResponse ?? "Sorry, I couldn't process that. Try again.",
          });
          _scrollToBottom();
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _isChatLoading = false;
          _chatHistory.add({
            'role': 'model',
            'text': 'Error: ${e.toString()}',
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
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFF7986CB)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      message['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isChatLoading) // Use the renamed variable
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                color: Colors.white,
                backgroundColor: Colors.transparent,
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
                      hintText: "Ask me about the weather...", // Updated hint
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 15),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}