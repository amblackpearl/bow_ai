# BowAI

A modern, feature-rich Flutter application that provides an intuitive and powerful chat interface powered by artificial intelligence.

## 🚀 Features

* **Multi-Model Support via OpenRouter:** Seamlessly switch between different AI models (including advanced models like Claude 3 Haiku) using the OpenRouter API.
* **Multimodal Capabilities:** 
  * Support for sending and processing images.
  * Document parsing and text extraction (PDF, DOCX, PPTX) for document-based interactions.
* **Speech-to-Text:** Voice input support for hands-free chat interaction.
* **Dynamic Theming:** Built-in Light and Dark mode with seamless transition and persistence.
* **Conversation Management:** Save, load, and manage past chat sessions.
* **Rich Text Rendering:** Markdown support for beautifully formatted AI responses, including code blocks.
* **Responsive UI:** Built with Material 3 for a modern and polished look across platforms.

## 🛠️ Tech Stack & Dependencies

* **Framework:** [Flutter](https://flutter.dev/) (SDK ^3.11.5)
* **Language:** Dart
* **Core Packages:**
  * `http`: For network requests to the OpenRouter API.
  * `flutter_markdown` / `markdown`: For rendering markdown text in chat messages.
  * `speech_to_text`: For voice recognition capabilities.
  * `syncfusion_flutter_pdf` & `archive`: For parsing text from PDF and DOCX/PPTX files.
  * `file_selector`: For cross-platform file and image picking.
  * `shared_preferences`: For saving local settings (like theme) and conversation history.
  * `flutter_dotenv`: For managing environment variables securely.
  * `google_fonts`: For modern typography styling.

## 📁 Project Structure

```text
lib/
├── main.dart                       # App entry point & theme configuration
├── models/
│   └── chat_message.dart           # Data models for chat messages
├── screens/
│   └── chat_screen.dart            # Main chat interface and logic
├── services/
│   ├── conversation_service.dart   # Manages saving/loading chat history locally
│   ├── document_parser_service.dart# Handles extracting text from uploaded files
│   ├── openrouter_service.dart     # Interacts with the OpenRouter API
│   └── theme_service.dart          # Manages light/dark mode state
└── widgets/
    └── chat_message_widget.dart    # Reusable UI component for individual messages
```

## ⚙️ Setup & Installation

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd bow_ai
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Environment Setup:**
   * Create a `.env` file in the root directory.
   * Add your OpenRouter API key:
     ```env
     OPENROUTER_API_KEY=your_api_key_here
     ```

4. **Run the app:**
   ```bash
   flutter run
   ```
   *Note: On Linux desktop, make sure you have the required build tools installed.*

## 📱 Platform Support

* Linux (Desktop)
* Web
* iOS / Android / Windows / macOS (via standard Flutter build targets)
