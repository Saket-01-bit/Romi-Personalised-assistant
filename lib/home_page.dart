import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:romeo/feature_box.dart';
import 'package:romeo/groq_services.dart';
import 'package:romeo/pallete.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// ================= MODELS =================

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatHistory {
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;

  ChatHistory({
    required this.title,
    required this.messages,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// ================= MAIN =================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final GroqServices _groqServices = GroqServices();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _lastWords = '';
  bool _isSpeaking = false;
  bool _isLoading = false;
  bool _isSpeechInitialized = false;
  bool _isDarkMode = false; // Theme mode state

  List<ChatMessage> _messages = [];
  List<ChatHistory> _historyList = [];
  int? _selectedHistoryIndex;

  /// ================= INIT =================

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  Future<void> _initializeSpeech() async {
    try {
      _isSpeechInitialized = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech error: $error'),
        onStatus: (status) => debugPrint('Speech status: $status'),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to initialize speech: $e');
    }
  }

  void _initializeTts() {
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setErrorHandler((error) {
      debugPrint('TTS error: $error');
      if (mounted) setState(() => _isSpeaking = false);
    });

    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setPitch(1.0);
    _flutterTts.setVolume(1.0);
  }

  /// ================= SPEECH =================

  Future<void> _startListening() async {
    if (!_isSpeechInitialized) return;

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenMode: ListenMode.confirmation,
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error starting listening: $e');
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error stopping listening: $e');
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) {
      setState(() {
        _lastWords = result.recognizedWords;
      });
    }
  }

  /// ================= TTS =================

  String _cleanTextForTTS(String text) {
    return text
        .replaceAll(RegExp(r'[*_`#>]'), '')
        .replaceAll(RegExp(r'•'), '')
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(':', '. ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _systemSpeak(String content) async {
    try {
      final cleaned = _cleanTextForTTS(content);

      if (_isSpeaking) {
        await _flutterTts.stop();
        if (mounted) setState(() => _isSpeaking = false);
      } else {
        await _flutterTts.speak(cleaned);
        if (mounted) setState(() => _isSpeaking = true);
      }
    } catch (e) {
      debugPrint('Error in TTS: $e');
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  /// ================= CHAT =================

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(text: text.trim(), isUser: true);

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _chatController.clear();
    _scrollToBottom();

    try {
      final response = await _groqServices.isArtPrompt(text.trim());

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: response, isUser: false));
          _isLoading = false;
        });

        _scrollToBottom();

        // Uncomment to enable TTS
        // await _systemSpeak(response);
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Sorry, an error occurred. Please try again.',
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    }
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

  /// ================= HISTORY =================

  void _saveCurrentChat() {
    if (_messages.isEmpty) return;

    final String title = _messages.first.text.length > 30
        ? '${_messages.first.text.substring(0, 30)}...'
        : _messages.first.text;

    _historyList.insert(
      0,
      ChatHistory(
        title: title,
        messages: List.from(_messages),
      ),
    );
  }

  void _loadChat(int index) {
    if (index < 0 || index >= _historyList.length) return;

    setState(() {
      _messages = List.from(_historyList[index].messages);
      _selectedHistoryIndex = index;
    });

    Navigator.pop(context);
    _scrollToBottom();
  }

  void _startNewChat() {
    _saveCurrentChat();

    setState(() {
      _messages.clear();
      _selectedHistoryIndex = null;
    });

    Navigator.pop(context);
  }

  void _deleteChat(int index) {
    setState(() {
      _historyList.removeAt(index);
      if (_selectedHistoryIndex == index) {
        _messages.clear();
        _selectedHistoryIndex = null;
      } else if (_selectedHistoryIndex != null && _selectedHistoryIndex! > index) {
        _selectedHistoryIndex = _selectedHistoryIndex! - 1;
      }
    });
  }

  /// ================= VOICE HANDLER =================

  Future<void> _handleVoiceButton() async {
    // Stop speaking if currently speaking
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    // Start listening if not listening
    if (await _speechToText.hasPermission && _speechToText.isNotListening) {
      await _startListening();
    }
    // Stop listening and populate text field
    else if (_speechToText.isListening) {
      await _stopListening();

      // Write the transcribed text to the text field
      if (_lastWords.trim().isNotEmpty && mounted) {
        setState(() {
          _chatController.text = _lastWords;
        });
      }
    }
  }

  /// ================= DISPOSE =================

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// ================= THEME =================

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  Color _getColor(Color lightColor, Color darkColor) {
    return _isDarkMode ? darkColor : lightColor;
  }

  /// ================= UI BUILDERS =================

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          FeatureBox(
            color: _getColor(Pallete.lightCardColor, Pallete.darkCardColor),
            headerText: 'Chat',
            descriptionText: 'A smarter way to stay organized and informed.',
          ),
          FeatureBox(
            color: _getColor(Pallete.lightCardColor, Pallete.darkCardColor),
            headerText: 'Voice',
            descriptionText: 'Talk naturally with your AI assistant.',
          ),
          FeatureBox(
            color: _getColor(Pallete.lightCardColor, Pallete.darkCardColor),
            headerText: 'Romi',
            descriptionText: 'Smart voice assistant powered by Groq.',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
        msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          /// ASSISTANT AVATAR
          if (!msg.isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 6, bottom: 2),
              child: CircleAvatar(
                radius: 14,
                backgroundColor:
                _getColor(Pallete.lightAssistantCircleColor, Pallete.darkAssistantCircleColor),
                backgroundImage: const AssetImage('assets/images/virtualAssistant.png'),
              ),
            ),

          /// MESSAGE BUBBLE (floating pill, soft shadow, no hard border)
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? _getColor(Pallete.lightMainFontColor, Pallete.darkUserBubbleColor)
                    : _getColor(Pallete.lightCardColor, Pallete.darkCardColor),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(msg.isUser ? 18 : 6),
                  bottomRight: Radius.circular(msg.isUser ? 6 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isDarkMode ? 0.25 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: msg.isUser
                  ? SelectionArea(
                child: SelectableText(
                  msg.text,
                  style: const TextStyle(
                    color: Pallete.whiteColor,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              )
                  : SelectionArea(
                child: MarkdownBody(
                  data: msg.text,
                  selectable: false,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontSize: 15,
                      height: 1.4,
                    ),
                    strong: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.bold,
                    ),
                    em: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontSize: 15,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                    h1: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    h2: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    h3: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    listBullet: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontSize: 15,
                    ),
                    code: TextStyle(
                      backgroundColor: _getColor(
                        Pallete.lightBackgroundColor,
                        Pallete.darkBackgroundColor,
                      ),
                      color: _getColor(Pallete.lightAssistantCircleColor, Pallete.darkAccentColor),
                      fontSize: 13.5,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: _getColor(Pallete.lightBackgroundColor, Pallete.darkBackgroundColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      color: _getColor(Pallete.lightBackgroundColor, Pallete.darkBackgroundColor),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    tableBorder: TableBorder.all(
                      color: _getColor(Pallete.lightBorderColor, Pallete.darkBorderColor),
                      width: 1,
                    ),
                    tableHead: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tableBody: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                      fontSize: 13.5,
                    ),
                    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: _getColor(Pallete.lightBorderColor, Pallete.darkBorderColor),
                        ),
                      ),
                    ),
                  ),
                  onTapLink: (text, href, title) {
                    // Links are display-only for now; no navigation wired up.
                  },
                ),
              ),
            ),
          ),

          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildLoadingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              child: CircleAvatar(
                radius: 14,
                backgroundColor:
                _getColor(Pallete.lightAssistantCircleColor, Pallete.darkAssistantCircleColor),
                backgroundImage: const AssetImage('assets/images/virtualAssistant.png'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _getColor(Pallete.lightCardColor, Pallete.darkCardColor),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isDarkMode ? 0.25 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _getColor(Pallete.lightAssistantCircleColor, Pallete.darkAccentColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool highlighted = false,
    bool filled = false,
    String? tooltip,
  }) {
    final bgColor = filled || highlighted
        ? _getColor(Pallete.lightMainFontColor, Pallete.darkUserBubbleColor)
        : _getColor(Pallete.lightCardColor, Pallete.darkCardColor);
    final iconColor = filled || highlighted
        ? Pallete.whiteColor
        : _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: iconColor),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      color: _getColor(Pallete.lightBackgroundColor, Pallete.darkBackgroundColor),
      child: SafeArea(
        child: Row(
          children: [
            /// VOICE BUTTON
            _buildRoundIconButton(
              icon: _isSpeaking
                  ? Icons.volume_off
                  : _speechToText.isListening
                  ? Icons.stop
                  : Icons.mic,
              onPressed: _handleVoiceButton,
              highlighted: _speechToText.isListening || _isSpeaking,
              tooltip: _isSpeaking
                  ? 'Stop Speaking'
                  : _speechToText.isListening
                  ? 'Stop Listening'
                  : 'Start Voice Input',
            ),
            const SizedBox(width: 8),

            /// TEXT INPUT (floating pill, soft shadow, no border)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _getColor(Pallete.lightCardColor, Pallete.darkCardColor),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _chatController,
                  onSubmitted: _sendMessage,
                  textInputAction: TextInputAction.send,
                  maxLines: null,
                  style: TextStyle(color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor)),
                  decoration: InputDecoration(
                    hintText: _speechToText.isListening
                        ? (_lastWords.isEmpty ? 'Listening...' : _lastWords)
                        : 'Type a message...',
                    hintStyle: TextStyle(
                      color: _speechToText.isListening
                          ? _getColor(Pallete.lightAssistantCircleColor, Pallete.darkUserBubbleColor)
                          : _getColor(
                        Pallete.lightMainFontColor.withOpacity(0.45),
                        Pallete.darkMainFontColor.withOpacity(0.45),
                      ),
                      fontStyle: _speechToText.isListening ? FontStyle.italic : FontStyle.normal,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            /// SEND BUTTON
            _buildRoundIconButton(
              icon: Icons.arrow_upward_rounded,
              onPressed: () => _sendMessage(_chatController.text),
              filled: true,
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _getColor(Pallete.lightBackgroundColor, Pallete.darkBackgroundColor),
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: _getColor(
                Pallete.lightFirstSuggestionBoxColor.withOpacity(0.1),
                Pallete.darkFirstSuggestionBoxColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Chat History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                    ),
                  ),
                ),

                /// THEME TOGGLE
                Row(
                  children: [
                    Icon(
                      Icons.wb_sunny,
                      size: 20,
                      color: _getColor(Pallete.lightAccentColor, Pallete.darkAccentColor),
                    ),
                    Switch(
                      value: _isDarkMode,
                      onChanged: (value) => _toggleTheme(),
                      activeColor: _getColor(Pallete.lightFirstSuggestionBoxColor, Pallete.darkFirstSuggestionBoxColor),
                    ),
                    Icon(
                      Icons.nightlight_round,
                      size: 20,
                      color: _getColor(Pallete.lightAccentColor, Pallete.darkAccentColor),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// NEW CHAT BUTTON
          ListTile(
            leading: Icon(
              Icons.add_circle_outline,
              color: _getColor(Pallete.lightFirstSuggestionBoxColor, Pallete.darkFirstSuggestionBoxColor),
            ),
            title: Text(
              'New Chat',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
              ),
            ),
            onTap: _startNewChat,
          ),

          Divider(color: _getColor(Pallete.lightBorderColor, Pallete.darkBorderColor)),

          /// HISTORY LIST
          Expanded(
            child: _historyList.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No chat history yet',
                  style: TextStyle(
                    color: _getColor(
                      Pallete.lightMainFontColor.withOpacity(0.5),
                      Pallete.darkMainFontColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            )
                : ListView.builder(
              itemCount: _historyList.length,
              itemBuilder: (context, index) {
                final item = _historyList[index];
                final isSelected = _selectedHistoryIndex == index;

                return ListTile(
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
                    ),
                  ),
                  subtitle: Text(
                    '${item.messages.length} messages',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getColor(
                        Pallete.lightMainFontColor.withOpacity(0.6),
                        Pallete.darkMainFontColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: _getColor(
                    Pallete.lightFirstSuggestionBoxColor.withOpacity(0.1),
                    Pallete.darkFirstSuggestionBoxColor.withOpacity(0.2),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: _getColor(
                        Pallete.lightMainFontColor.withOpacity(0.6),
                        Pallete.darkMainFontColor.withOpacity(0.6),
                      ),
                    ),
                    onPressed: () => _deleteChat(index),
                  ),
                  onTap: () => _loadChat(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ================= MAIN BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getColor(Pallete.lightBackgroundColor, Pallete.darkBackgroundColor),
      appBar: AppBar(
        title: Text(
          'Romi',
          style: TextStyle(color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor)),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _getColor(Pallete.lightBackgroundColor, Pallete.darkBackgroundColor),
        iconTheme: IconThemeData(
          color: _getColor(Pallete.lightMainFontColor, Pallete.darkMainFontColor),
        ),
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          /// CHAT MESSAGES
          Expanded(
            child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
          ),

          /// INPUT AREA
          _buildInputArea(),
        ],
      ),
    );
  }
}