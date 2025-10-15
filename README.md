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

3. Configure environment variables:
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your actual API keys
# SUPABASE_URL=your_supabase_url
# SUPABASE_ANON_KEY=your_supabase_anon_key
# REPLICATE_API_KEY=your_replicate_api_key
```

4. Run the app with environment variables:
```bash
flutter run --dart-define-from-file=.env
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

## Garment Detection Service (local)

The SerpAPI pipeline now expects a local detector that crops up to four dominant garments before running Google Lens searches. Start it with:

```bash
pip install -r server/requirements.txt
uvicorn server.fashion_detector_server:app --host 0.0.0.0 --port 8000
```

Each run is archived under `D:/SerpAPI Google Lens/Crops/<timestamp>` with the original image, an overlay showing bounding boxes + labels, and the individual crop JPEGs. The service also uploads the original image and crops to ImgBB when an API key is provided. Set `CROP_OUTPUT_DIR` if you prefer a different folder and define `IMGBB_API_KEY` in the shell (or `server/.env`) so the Flutter app still receives public URLs.

When testing on the Android emulator point `SERP_DETECTOR_ENDPOINT` at `http://10.0.2.2:8000/detect`. For other devices use your host machine's reachable address.
