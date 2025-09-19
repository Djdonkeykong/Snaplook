# Generate Widget with Design System

Generate a Flutter widget: $ARGUMENTS

The widget must follow our design system:

**Colors**: Use Theme.of(context).colorScheme tokens
- primary, secondary, surface, error, etc.
- Never use Colors.blue, Colors.red, etc.

**Typography**: Use Theme.of(context).textTheme
- headlineLarge/Medium/Small for headers
- titleLarge/Medium/Small for titles  
- bodyLarge/Medium/Small for content
- labelLarge/Medium/Small for labels

**Spacing**: Use theme extensions for spacing
- final spacing = Theme.of(context).extension<AppSpacingExtension>()!;
- spacing.xs (4px), spacing.s (8px), spacing.m (16px), etc.

**Border Radius**: Use theme extensions for radius
- final radius = Theme.of(context).extension<AppRadiusExtension>()!;
- radius.small (8px), radius.medium (12px), radius.large (16px)

**Structure**:
- Include proper documentation
- Use const constructors
- Add accessibility semantics
- Support both themes
- Follow naming conventions