# CACHY

<p align="center">
  <img src="resources/Banner.png" alt="CACHY Banner">
</p>

Cachy is a personal AI-based memory assistant that runs completely offline. It uses the Gemma 4 E2B model via Google's LiteRT-LM runtime to store and retrieve your memories through natural language conversation.


## Features

- **AI-powered memory management** -- Chat with an on-device LLM to store (write) or recall (read) memories.
- **Fully offline** -- No internet required after the initial model download. All inference runs locally on CPU.
- **Background downloads** -- Model is downloaded via flutter_downloader with system notification progress and pause/resume support.
- **Manual memory CRUD** -- View, search, create, and delete memories from a dedicated list page.
- **Deeper search** -- When keyword matching fails, the app can chunk-search every stored memory for relevant results.
- **JetBrains Mono typography** -- Clean monospace interface.


## How It Works

1. Type a message in the prompt box and tap Send.
2. The Gemma 4 model classifies your input:
   - **Write** -- The model formalizes the text and saves it as a new memory in the local SQLite database.
   - **Read** -- The model extracts keywords, searches the database using SQL LIKE, feeds the results back to the model, and returns a natural-language answer.
3. If no relevant memory is found with keywords and the database is large, the app offers a deeper search that iterates over all memories in chunks.
<p align="center">
  <img src="resources/Project Cachy.png" alt="CACHY Banner">
</p>




## Project Structure

```
lib/
├── main.dart                          # App entry point, theme, flutter_downloader init
├── home_page.dart                     # Shell with IndexedStack (AI + List tabs)
├── database/
│   └── database_helper.dart           # SQLite CRUD singleton (memories table)
├── model/
│   └── memories_model.dart            # Memory data class with toMap/fromMap
├── pages/
│   ├── ai_page.dart                   # AI chat interface, model management, download UI
│   └── memories_page.dart             # Memories list with search, create, delete
└── widget/
    ├── bottom_nav_bar.dart            # Bottom navigation (AI / List tabs)
    ├── create_memory_dialog.dart      # Dialog for manually adding a memory
    ├── delete_conform_dialog.dart     # Confirmation dialog before deletion
    ├── memory_detail.dialog.dart      # Dialog showing full memory content
    └── snackbar_message.dart          # Reusable floating snackbar helper
```


## Tech Stack

| Layer          | Technology                              |
|----------------|-----------------------------------------|
| Framework      | Flutter / Dart                          |
| AI Engine      | flutter_litert_lm (LiteRT-LM / Gemma 4) |
| Local Database | sqflite (SQLite)                        |
| Model Download | flutter_downloader                      |
| File Access    | path_provider, permission_handler       |
| Fonts          | google_fonts (JetBrains Mono)           |
| Date Format    | intl                                    |

## Prerequisites

- Flutter SDK (3.24+ recommended, Dart 3.4+)
- Android device or emulator (iOS requires running `scripts/build_ios_frameworks.sh` from the plugin checkout)
- ~2.6 GB free storage for the model file
- ~3 GB free RAM on device for model inference


## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/cachy.git
   cd cachy
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

4. On first launch, the app will prompt you to download the Gemma 4 E2B model (~2.58 GB). Tap **Download Model** -- the download runs in the background with system notification progress.


## Building

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release

# iOS (after building LiteRTLM.xcframework)
flutter build ios --release
```


## Supported Models

The app uses Gemma 4 E2B Instruct from HuggingFace:

- **Model**: `litert-community/gemma-4-E2B-it-litert-lm`
- **Format**: `.litertlm` (LiteRT-LM bundle format)
- **Size**: 2.58 GB
- **License**: Apache-2.0

To switch to a different model, update `_modelUrl` and `_expectedModelSize` in `lib/pages/ai_page.dart`. The plugin supports Qwen 3, Qwen 2.5, DeepSeek R1, Phi-4 Mini, and Gemma 4 E4B.



## License

This project is licensed under the MIT License -- see the LICENSE file for details.

## Images
<img width="2160" height="2400" alt="page1" src="https://github.com/user-attachments/assets/6374fb0c-18bb-4346-a9c9-ae24eae7aeb5" />

<img width="2160" height="2400" alt="page2" src="https://github.com/user-attachments/assets/7afa4825-c462-4ae4-a6e4-3f61209e7399" />

<img width="2160" height="2400" alt="page3" src="https://github.com/user-attachments/assets/dcbf3bb2-948f-4686-be17-7923505e6d17" />

<img width="1080" height="2400" alt="page4" src="https://github.com/user-attachments/assets/28d50356-7fc9-4b4f-b411-4978cc27eff4" />


