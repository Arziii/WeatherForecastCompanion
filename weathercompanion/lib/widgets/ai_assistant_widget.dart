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
  // Using gemini-pro, compatible with v1beta used by flutter_gemini 3.0.0
  // Or 'gemini-flash-latest' if preferred and available/working
  final String _modelName = 'gemini-pro';
  // final String _modelName = 'gemini-flash-latest'; // Keep if this was intended

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
    FocusScope.of(context).unfocus(); // Hide keyboard

    setState(() {
      _chatHistory.add({'isUser': true, 'message': userMessage});
      _isAILoading = true;
    });
    _scrollToBottom();

    final contextPrompt = _generateContextPrompt();
    final fullPrompt = "$contextPrompt\n\nUser Question: $userMessage";
    developer.log("Sending AI Assistant prompt:\n$fullPrompt",
        name: "AiAssistantWidget");

    try {
      // Switched from gemini.chat() to gemini.text()
      final response = await gemini.text(
        fullPrompt,
        // modelName: _modelName, // modelName is optional for .text()
      );

      // Access output differently for .text()
      final aiResponse =
          response?.output ?? "Sorry, I couldn't understand that.";
      developer.log("AI Assistant response: $aiResponse",
          name: "AiAssistantWidget");

      setState(() {
        _chatHistory.add({'isUser': false, 'message': aiResponse});
        _isAILoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      developer.log('AI Assistant Error: $e',
          name: 'AiAssistantWidget', error: e);
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
    // --- MODIFIED: Get Theme ---
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // --- END MODIFIED ---

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // --- MODIFIED: Use theme colors ---
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.2)),
        // --- END MODIFIED ---
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Ask Mr. WFC (AI Assistant)",
            // --- MODIFIED: Use theme text styles ---
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            // --- END MODIFIED ---
          ),
          const SizedBox(height: 10),
          Container(
            height: 200, // Fixed height for chat history
            decoration: BoxDecoration(
              // --- MODIFIED: Use theme colors ---
              color: theme.scaffoldBackgroundColor
                  .withOpacity(0.5), // Slightly different background for chat
              borderRadius: BorderRadius.circular(10),
              // --- END MODIFIED ---
            ),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final chat = _chatHistory[index];
                final bool isUser = chat['isUser'] ?? false;
                final message = chat['message'] ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start, // Align top
                    children: [
                      if (!isUser)
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 8.0, top: 5.0), // Align icon better
                          child: Image.asset('assets/images/logo.png',
                              width: 24, height: 24),
                        ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            // --- MODIFIED: Use theme colors ---
                            color: isUser
                                ? theme.colorScheme.primary
                                    .withOpacity(0.8) // User bubble
                                : theme.colorScheme
                                    .secondaryContainer, // AI bubble
                            borderRadius: BorderRadius.circular(12),
                            // --- END MODIFIED ---
                          ),
                          child: Text(
                            message,
                            // --- MODIFIED: Use theme colors ---
                            style: TextStyle(
                                color: isUser
                                    ? theme.colorScheme
                                        .onPrimary // Text on primary
                                    : theme.colorScheme
                                        .onSecondaryContainer, // Text on secondary container
                                fontSize: 15),
                            // --- END MODIFIED ---
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
                  // --- MODIFIED: Use theme colors ---
                  style:
                      TextStyle(color: theme.colorScheme.onSecondaryContainer),
                  decoration: InputDecoration(
                    hintText: "Ask about the weather...",
                    hintStyle: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer
                            .withOpacity(0.7)),
                    filled: true,
                    fillColor: theme.colorScheme.secondaryContainer,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    isDense: true,
                  ),
                  // --- END MODIFIED ---
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send, // Use send action
                ),
              ),
              const SizedBox(width: 8),
              _isAILoading
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          // --- MODIFIED: Use theme colors ---
                          child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                              strokeWidth: 2.5)),
                      // --- END MODIFIED ---
                    )
                  : IconButton(
                      // --- MODIFIED: Use theme colors ---
                      icon: Icon(Icons.send, color: theme.colorScheme.primary),
                      // --- END MODIFIED ---
                      iconSize: 24,
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
