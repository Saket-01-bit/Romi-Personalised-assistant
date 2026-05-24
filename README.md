# Romi – Personalized AI Assistant

Romi is a Flutter-based AI assistant that combines voice interaction, conversational AI, and real-time responses using Groq’s LLM (LLaMA 3). It is designed to function as a smart personal assistant with both voice and text capabilities.

---

## Features

- AI chat powered by Groq (LLaMA 3.1)
- Speech-to-text input
- Text-to-speech responses
- Context-aware conversation (chat memory)
- Prompt detection (text vs image intent)
- Fast responses via Groq API
- Clean and modern Flutter UI

---

## Tech Stack

- Flutter
- Dart
- Groq API (LLaMA 3.1)
- speech_to_text
- flutter_tts
- http
- flutter_dotenv

---

## Project Structure
- `lib/`
  - `main.dart` - Entry point of the app
  - `services/` - API and speech services
    - `groq_api_service.dart` - Handles communication with Groq API
    - `speech_service.dart` - Manages speech-to-text and text-to-speech
  - `widgets/` - Reusable UI components
    - `chat_bubble.dart` - Chat bubble widget for messages
    - `input_field.dart` - Input field for user messages
  - `screens/` - App screens
    - `home_screen.dart` - Main screen with chat interface

## Setup Instructions
1. Clone the repository:
   ```bash
   git clone
    ```
2. Navigate to the project directory:
3. ```bash
   cd romi
   ```
4. Install dependencies:
5. ```bash
   flutter pub get
   ```
6. Create a `.env` file in the root directory and add your Groq API key:
   ```
   GROQ_API_KEY=your_groq_api_key_here
   ```
   7. Run the app:
      ```bash
      flutter run
      ```
## Future Enhancements
- Add support for image generation and recognition
- Implement user authentication and personalized settings
- Integrate with calendar and task management APIs
- Improve error handling and offline capabilities
