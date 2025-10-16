import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/difficulty_preference_service.dart';
import 'daily_surface.dart';

/// A card widget displaying puzzle information with difficulty chips and CTA buttons.
class PuzzleCard extends StatefulWidget {
  const PuzzleCard({
    super.key,
    required this.metadata,
    this.onDailyChallenge,
    this.onRandomPuzzle,
    this.onDifficultySelected,
  });

  final PuzzleMetadata metadata;
  final VoidCallback? onDailyChallenge;
  final VoidCallback? onRandomPuzzle;
  final Function(String difficulty)? onDifficultySelected;

  @override
  State<PuzzleCard> createState() => _PuzzleCardState();
}

class _PuzzleCardState extends State<PuzzleCard> {
  String? _selectedDifficulty;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferredDifficulty();
  }

  Future<void> _loadPreferredDifficulty() async {
    final preferred = await DifficultyPreferenceService.getPreferredDifficulty(widget.metadata.type);
    if (mounted) {
      setState(() {
        _selectedDifficulty = preferred;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.metadata.primaryAccentColor.withOpacity(0.1),
              widget.metadata.secondaryAccentColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.metadata.primaryAccentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.metadata.icon,
                      color: widget.metadata.primaryAccentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.metadata.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          widget.metadata.category.displayName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Difficulty radio buttons
              if (_isLoading)
                const SizedBox(height: 32) // Placeholder while loading
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Difficulty:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: widget.metadata.supportedDifficulties.map((difficulty) {
                        // Use chip style for Kakuro, radio buttons for others
                        if (widget.metadata.type.key == 'kakuro_classic') {
                          return _DifficultyChip(
                            difficulty: difficulty,
                            color: widget.metadata.primaryAccentColor,
                            isSelected: _selectedDifficulty == difficulty,
                            onTap: () => _onDifficultySelected(difficulty),
                          );
                        } else {
                          return _DifficultyRadioButton(
                            difficulty: difficulty,
                            color: widget.metadata.primaryAccentColor,
                            isSelected: _selectedDifficulty == difficulty,
                            onChanged: (value) => _onDifficultySelected(difficulty),
                          );
                        }
                      }).toList(),
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
              
              // Daily Challenge Surface
              DailySurface(
                puzzleType: widget.metadata.type,
                compact: true,
              ),
              
              const SizedBox(height: 12),
              
              // Random Puzzle Button
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  label: 'Random Puzzle',
                  icon: Icons.shuffle,
                  isPrimary: false,
                  color: widget.metadata.primaryAccentColor,
                  onPressed: widget.onRandomPuzzle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDifficultySelected(String difficulty) {
    setState(() {
      _selectedDifficulty = difficulty;
    });
    
    // Save the preference
    DifficultyPreferenceService.setPreferredDifficulty(widget.metadata.type, difficulty);
    
    if (widget.onDifficultySelected != null) {
      widget.onDifficultySelected!(difficulty);
    }
  }
}

/// A chip for difficulty selection (radio button functionality with chip visuals).
class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    required this.difficulty,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String difficulty;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? color 
              : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? color 
                : color.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          difficulty,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// A radio button for difficulty selection.
class _DifficultyRadioButton extends StatelessWidget {
  const _DifficultyRadioButton({
    required this.difficulty,
    required this.color,
    required this.isSelected,
    required this.onChanged,
  });

  final String difficulty;
  final Color color;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: difficulty,
          groupValue: isSelected ? difficulty : null,
          onChanged: (value) => onChanged(value != null),
          activeColor: color,
        ),
        Text(
          difficulty,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// An action button for puzzle modes.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.color,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? color : colorScheme.surface,
        foregroundColor: isPrimary ? Colors.white : color,
        elevation: isPrimary ? 2 : 0,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isPrimary ? Colors.transparent : color.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
