import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'dart:async'; // For the delayed scroll

class AiAssistantWidget extends StatefulWidget {
  const AiAssistantWidget({super.key});

  @override
  State<AiAssistantWidget> createState() => _AiAssistantWidgetState();
}

class _AiAssistantWidgetState extends State<AiAssistantWidget> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Gemini _gemini = Gemini.instance;

  // This FocusNode is now the key
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  final List<Map<String, String>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _chatHistory.add({
      'role': 'model',
      'text':
          'Hello! Companion! I am your AI assistant. Feel free to ask me anything about the weather or just have a chat!',
    });

    // Add the listener
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

  // This function will now work correctly
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Delay to allow keyboard to start animating
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Find the RenderObject of this widget
          final RenderBox renderBox = context.findRenderObject() as RenderBox;
          // Find its position relative to the nearest Viewport
          // (which is the SingleChildScrollView)
          final offset = renderBox.localToGlobal(Offset.zero, 
              ancestor: Scrollable.of(context).context.findRenderObject());

          // Animate the scroll view
          Scrollable.of(context).position.ensureVisible(
                renderBox,
                alignment: 0.1, // Aligns to 10% from the top of the viewport
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
    _focusNode.unfocus(); // Hide keyboard

    setState(() {
      _isLoading = true;
      _chatHistory.add({'role': 'user', 'text': userMessage});
      _scrollToBottom();
    });

    _gemini
        .chat(
      [Content(parts: [Part.text(userMessage)], role: 'user')],
      modelName: 'gemini-pro',
    )
        .then((response) {
      final String? modelResponse = response?.output;
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          _isLoading = false;
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
          if (_isLoading)
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
                    focusNode: _focusNode, // Assign the FocusNode
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Ask me anything...",
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