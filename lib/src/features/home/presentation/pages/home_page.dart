import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/providers/image_provider.dart';
import '../../../detection/presentation/pages/detection_page.dart';
import '../../../detection/domain/services/detection_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ImagePicker _picker = ImagePicker();


  static const List<Map<String, dynamic>> _trendingStyles = [
    {
      'title': 'Minimalist',
      'subtitle': 'Clean & Simple',
      'icon': Icons.minimize_outlined,
      'color': Color(0xFFE3F2FD),
    },
    {
      'title': 'Vintage',
      'subtitle': 'Retro Vibes',
      'icon': Icons.history_outlined,
      'color': Color(0xFFF3E5F5),
    },
    {
      'title': 'Casual',
      'subtitle': 'Everyday Comfort',
      'icon': Icons.weekend_outlined,
      'color': Color(0xFFE8F5E8),
    },
    {
      'title': 'Business',
      'subtitle': 'Professional',
      'icon': Icons.business_center_outlined,
      'color': Color(0xFFFFF3E0),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo/Brand on the left
            Image.asset(
              'assets/images/logo.png',
              height: 35,
              fit: BoxFit.contain,
            ),
            // Search icon on the right
            IconButton(
              onPressed: () {
                // TODO: Implement search functionality
              },
              icon: Icon(
                Icons.search,
                color: AppColors.tertiary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(spacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inspiration Section
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.tertiary,
                        borderRadius: BorderRadius.circular(radius.large),
                      ),
                      child: Stack(
                        children: [
                          // Background image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(radius.large),
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              child: Image.asset(
                                'assets/images/pexels-mizunokozuki-13929216.jpg',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                alignment: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // Overlay with text
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(radius.large),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                          // Content
                          Positioned(
                            left: spacing.l,
                            bottom: spacing.l,
                            right: spacing.l,
                            child: GestureDetector(
                              onTap: () => _showImageSourceDialog(context),
                              child: Center(
                                child: Text(
                                  'Find Your\nInspiration',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                    fontSize: (Theme.of(context).textTheme.headlineLarge?.fontSize ?? 32) * 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.xl),

                    // Trending Styles Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Trending Styles',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: Navigate to full trends page
                          },
                          child: Text(
                            'See all',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.m),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _trendingStyles.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final style = _trendingStyles[index];
                          return Padding(
                            padding: EdgeInsets.only(right: spacing.m),
                            child: _TrendingStyleCard(
                              title: style['title'] as String,
                              subtitle: style['subtitle'] as String,
                              icon: style['icon'] as IconData,
                              color: style['color'] as Color,
                              onTap: () {
                                // TODO: Navigate to style details
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: spacing.xl),
                  ],
                ),
              ),
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radius.large),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(spacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            SizedBox(height: spacing.l),
            Text(
              'Choose Image Source',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.l),
            Row(
              children: [
                Expanded(
                  child: _SourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                SizedBox(width: spacing.m),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.l),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        ref.read(selectedImageProvider.notifier).setImage(image);

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DetectionPage(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _importFromSocialMedia() {
    // TODO: Implement social media import
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Social media import coming soon!'),
      ),
    );
  }

  Future<void> _testApiConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing API connection...'),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      final detectionService = DetectionService();
      final isConnected = await detectionService.testApiConnection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isConnected ? 'API connection successful!' : 'API connection failed!',
            ),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing API: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.medium),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: spacing.l),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(radius.medium),
          ),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(height: spacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.medium),
        child: Container(
          padding: EdgeInsets.all(spacing.m),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(radius.medium),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(radius.small),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(height: spacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: spacing.xs / 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _TrendingStyleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TrendingStyleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.tertiary,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.tertiary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}