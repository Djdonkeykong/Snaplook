# Snaplook - AI Fashion Detection App

Snaplook is a Flutter mobile application that uses AI to analyze fashion images and find similar clothing items from a comprehensive database. Upload photos or capture images to discover fashion recommendations powered by advanced computer vision.

## Features

- 📸 **Image Capture & Upload**: Take photos or select from gallery
- 🤖 **AI Fashion Analysis**: Powered by Claude Sonnet 4 via Replicate
- 🔍 **Product Matching**: Find similar items from 500k+ product database
- 📱 **Cross-Platform**: Works on both iOS and Android
- 🎨 **Modern UI**: Clean, intuitive design inspired by CalAI
- 📲 **Social Integration**: Import from Instagram, TikTok, YouTube (coming soon)

## Technology Stack

- **Frontend**: Flutter with Riverpod state management
- **Backend**: Supabase for database and authentication
- **AI**: Replicate API with Claude Sonnet 4 model
- **Image Processing**: Flutter image plugins
- **Architecture**: Clean architecture with feature-based structure

## Getting Started

### Prerequisites

- Flutter SDK (>=3.3.0)
- Dart SDK
- Android Studio / Xcode
- Supabase account
- Replicate API key

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Djdonkeykong/Snaplook.git
cd Snaplook
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure environment variables in `lib/src/core/constants/app_constants.dart`:
```dart
static const String supabaseUrl = 'https://tlqpkoknwfptfzejpchy.supabase.co';
static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRscXBrb2tud2ZwdGZ6ZWpwY2h5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDAzMzM3MSwiZXhwIjoyMDY5NjA5MzcxfQ._oMzqi-ikCHrJmcXI-D5M0d-6PakOWzVYDBehoW27Ow';
static const String replicateApiKey = 'YOUR_REPLICATE_API_KEY';
```

4. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart
└── src/
    ├── core/
    │   ├── constants/
    │   ├── services/
    │   └── utils/
    ├── features/
    │   ├── home/
    │   ├── detection/
    │   └── results/
    └── shared/
        ├── widgets/
        ├── models/
        └── providers/
```

## Configuration

### Supabase Setup

1. Create a new Supabase project
2. Set up your product database schema
3. Configure authentication (optional)
4. Update the constants with your project URLs and keys

### Replicate Setup

1. Sign up for Replicate API
2. Set up Claude Sonnet 4 model
3. Get your API key and model version
4. Update the constants

### MCP Servers (Optional)

Configure MCP servers for enhanced development experience:
- Dart MCP Server
- Firebase MCP Server
- GitHub MCP Server
- Replicate MCP Server

## Development Commands

```bash
# Run app
flutter run

# Build for production
flutter build apk --release  # Android
flutter build ios --release  # iOS

# Run tests
flutter test

# Format code
dart format .

# Analyze code
flutter analyze
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and ensure code quality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions, please open an issue on GitHub or contact the development team.
