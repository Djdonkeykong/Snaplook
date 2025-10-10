# Flutter App Design System & Guidelines for Snaplook

## Project Overview
A Flutter mobile application for "Snaplook", an AI-powered fashion discovery app. Users can scan clothing items to find similar fashion products. The design features a clean white/black theme with red accent color.

## Design System Rules - ALWAYS FOLLOW THESE

### Colors
- **Primary Color**: `#FFFFFF` (Pure White) - Used for backgrounds, surfaces
- **Secondary Color**: `#f2003c` (Red) - Used for accents, highlights, and call-to-action elements
- **Black**: `#080808` (Near Black) - Used for text, icons, and secondary elements
- **Surface Colors**:
  - Main Surface: `#FFFFFF` (White)
  - Surface Variant: `#F9F9F9` (Very light gray)
  - Background: `#FFFFFF` (Pure white)
  - Outline: `#E5E7EB` (Light gray borders)
- **Text Colors**:
  - Primary Text: `#1c1c25` (Dark text on light)
  - Secondary Text: `#6B7280` (Muted gray text)
  - Navigation Unselected: `#9CA3AF` (Light gray for inactive)
- **State Colors**:
  - Error: `#EF4444` (Red 500)
  - Success: `#22C55E` (Green 500)
  - Warning: `#F59E0B` (Amber 500)

### Corner Radius Standards
- **Small**: 8px - Small elements (chips, badges, small cards)
- **Medium**: 12px - Cards, containers, inputs
- **Large**: 16px - Modals, bottom sheets, large cards
- **Extra Large**: 28px - Buttons, major interactive elements

### Navigation System
- **Bottom Navigation**: Uses IndexedStack to preserve state between tabs
- **Tabs**: Home (Camera), Wardrobe (Favorites), Discover (Search), Profile
- **Icons Only**: No text labels on navigation items
- **Active State**: Red accent (#f2003c)
- **Inactive State**: Light gray (#9CA3AF)

### Component Styles
- **Primary Actions**: Red background (#f2003c) with white text, rounded 28px
- **Secondary Actions**: White surface with light gray border, rounded 28px
- **Cards**: White surface with light gray borders (#E5E7EB)
- **Navigation Items**: Rounded containers with smooth transitions
- **Modal Sheets**: Rounded top corners, white surface
- **Back Buttons**: Light gray circle (#F3F4F6) with black icon

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
- **Primary elements**: Red accent (#f2003c), bold typography
- **Secondary elements**: Black text on white surfaces
- **Interactive states**: Smooth color transitions, subtle scale changes
- **Focus states**: Red accent border or background

## CRITICAL RULES & INSTRUCTIONS
- **ALWAYS use the Snaplook design system values above.**
- **Clean white/black aesthetic** - White backgrounds with black text and red accents
- **Red accents are key** - Use secondary color (#f2003c) for highlights, CTAs, and active states
- **Use IndexedStack navigation** - Preserve state between tabs for optimal UX
- Reference theme tokens for colors, fonts, and spacing using context extensions
- Use `AppColors.primary` for white, `AppColors.secondary` for red accent
- Use `context.spacing.m` and `context.radius.medium` for consistent spacing/radius

### UI Development Guidelines:
- Use `AppColors.primary` or `Colors.white` for backgrounds
- Use `AppColors.secondary` (#f2003c) for primary CTAs and accents
- Use `AppColors.black` or `Colors.black` for text and icons
- Use `context.spacing.m` for medium spacing (16px)
- Use `context.radius.medium` for medium border radius (12px)
- Buttons should have 28px border radius for modern look
- Always use theme extensions for custom properties: `AppSpacingExtension`, `AppRadiusExtension`
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