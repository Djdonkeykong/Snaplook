# Flutter App Design System & Guidelines for Snaplook

## Project Overview
A Flutter mobile application for "Snaplook", an AI-powered fashion discovery app. Users can scan clothing items to find similar fashion products. The design features a sophisticated dark theme with golden accents.

## Design System Rules - ALWAYS FOLLOW THESE

### Colors
- **Primary Color**: `#1c1c25` (Dark Navy/Charcoal) - Used for backgrounds, primary UI elements
- **Secondary Color**: `#fec948` (Golden Yellow) - Used for accents, highlights, and call-to-action elements
- **Surface Colors**:
  - Main Surface: `#1f1f28` (Dark Surface)
  - Surface Variant: `#252530` (Slightly Lighter Surface)
  - Navigation Background: `#1a1a22` (Darker Navigation)
- **Text Colors**:
  - Primary Text: `#E8E8EA` (Light text on dark)
  - Secondary Text: `#B8B8BA` (Muted text)
  - Navigation Unselected: `#6a6a75` (Muted for inactive tabs)
- **State Colors**:
  - Error: `#EF4444` (Red 500)
  - Success: `#22C55E` (Green 500)
  - Warning: `#F59E0B` (Amber 500)

### Corner Radius Standards
- **Small**: 8px - Small elements (chips, badges, small cards)
- **Medium**: 12px - Cards, containers, inputs
- **Large**: 16px - Modals, bottom sheets, large cards
- **Extra Large**: 24px - Special containers, hero elements

### Navigation System
- **Bottom Navigation**: Uses IndexedStack to preserve state between tabs
- **Tabs**: Home (Camera), Wardrobe (Favorites), Discover (Search), Profile
- **Icons Only**: No text labels on navigation items
- **Active State**: Golden yellow (#fec948) with subtle background highlight
- **Inactive State**: Muted gray (#6a6a75)

### Component Styles
- **Primary Actions**: Golden yellow background with dark text
- **Secondary Actions**: Dark surface with golden border
- **Cards**: Dark surface (#1f1f28) with subtle borders
- **Navigation Items**: Rounded containers with smooth transitions
- **Modal Sheets**: Rounded top corners, dark surface with lighter drag handle

### Typography Scale (Material 3)
- **Display Small**: 36px, Bold - Hero headings
- **Headline Small**: 24px, Bold - Section headers
- **Title Large**: 22px, SemiBold - Card titles
- **Title Medium**: 16px, Medium - Component titles
- **Title Small**: 14px, Medium - Small titles
- **Body Large**: 16px, Regular - Primary body text
- **Body Medium**: 14px, Regular - Secondary body text
- **Body Small**: 12px, Regular - Captions, labels

### Spacing System
- **XS**: 4px - Tight spacing, inner paddings
- **SM**: 8px - Small gaps, compact layouts
- **M**: 16px - Standard spacing, default padding
- **L**: 24px - Large spacing, section gaps
- **XL**: 32px - Extra large spacing
- **XXL**: 48px - Maximum spacing, major sections

### Visual Hierarchy
- **Primary elements**: Golden yellow accents, bold typography
- **Secondary elements**: Light text on dark surfaces
- **Interactive states**: Smooth color transitions, subtle scale changes
- **Focus states**: Golden border or background highlight

## CRITICAL RULES & INSTRUCTIONS
- **ALWAYS use the Snaplook design system values above.**
- **Force dark theme for consistent experience** - App should always use dark mode
- **Golden accents are key** - Use secondary color (#fec948) for highlights, CTAs, and active states
- **Use IndexedStack navigation** - Preserve state between tabs for optimal UX
- Reference theme tokens for colors, fonts, and spacing using context extensions
- Use `AppColors.primary` for dark navy, `AppColors.secondary` for golden yellow
- Use `context.spacing.m` and `context.radius.medium` for consistent spacing/radius

### UI Development Guidelines:
- Use `Theme.of(context).colorScheme.primary` for dark navy primary color
- Use `Theme.of(context).colorScheme.secondary` for golden yellow accents
- Use `context.spacing.m` for medium spacing (16px)
- Use `context.radius.medium` for medium border radius (12px)
- Always use theme extensions for custom properties: `AppSpacingExtension`, `AppRadiusExtension`
- Prefer dark surface colors for all backgrounds
- Include smooth transitions and animations for state changes
- Use Material 3 components with custom theming

### Navigation Implementation:
- Bottom navigation with 4 tabs: Home, Wardrobe, Discover, Profile
- Use `IndexedStack` to preserve page state when switching tabs
- Only icons in navigation - no text labels
- Golden yellow for active states, muted gray for inactive
- Smooth transitions between navigation states

### File Structure:
```
lib/
├── main.dart
├── core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── color_schemes.dart
│   │   ├── app_colors.dart
│   │   ├── app_spacing.dart
│   │   ├── app_radius.dart
│   │   └── theme_extensions.dart
│   └── constants/
├── shared/
│   ├── navigation/
│   │   └── main_navigation.dart
│   └── widgets/
└── src/features/
    ├── home/
    ├── wardrobe/
    ├── discover/
    ├── profile/
    └── results/
```

### Code Conventions:
- Use `const` constructors wherever possible
- Follow Material 3 component patterns with dark theme
- Include accessibility semantics and labels
- Use Riverpod for state management
- Use theme extensions consistently: `context.spacing.m`, `context.radius.large`
- Document custom components and design patterns

## Tech Stack
- Flutter 3.19+ (Material 3 with custom dark theme)
- State Management: Riverpod
- Theme: Custom Material 3 dark implementation
- Colors: Dark navy (#1c1c25) + Golden yellow (#fec948)
- Navigation: IndexedStack bottom navigation

## Development Commands
- `flutter run --dart-define-from-file=.env` - Start development with env file
- `flutter test` - Run tests
- `flutter build apk` - Build for Android
- `flutter analyze` - Static analysis
- `flutter pub get` - Get dependencies

## Custom Commands (if available)
- `/scan` - Test scanning functionality
- `/theme` - Apply theme updates
- `/nav` - Test navigation system