import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';
import '../../shared/providers/puzzle_local_store_providers.dart';
import '../../shared/services/puzzle_registry.dart';
import '../../shared/widgets/brainiax/brainiax_widgets.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/puzzle_card.dart';
import '../../shared/widgets/shimmer_widget.dart';
import 'puzzle_detail_sheet.dart';
import 'puzzle_launch_actions.dart';

class SelectScreen extends ConsumerStatefulWidget {
  const SelectScreen({super.key});

  @override
  ConsumerState<SelectScreen> createState() => _SelectScreenState();
}

class _SelectScreenState extends ConsumerState<SelectScreen> {
  final PuzzleRegistry _registry = PuzzleRegistry();
  bool _isLoading = true;
  List<PuzzleMetadata> _metadata = const <PuzzleMetadata>[];
  PuzzleLibraryFilter _filter = PuzzleLibraryFilter.all;

  @override
  void initState() {
    super.initState();
    _loadPuzzles();
  }

  void _loadPuzzles() {
    _registry.initialize();
    setState(() {
      _metadata = _registry.getAllPuzzleMetadata()
        ..sort(
          (a, b) => _librarySortKey(a.type).compareTo(_librarySortKey(b.type)),
        );
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PuzzleType>> favouriteTypesAsync = ref.watch(
      favouritePuzzleTypesProvider,
    );
    final Set<PuzzleType> favouriteTypes =
        favouriteTypesAsync.asData?.value.toSet() ?? const <PuzzleType>{};
    final List<PuzzleMetadata> filtered = _applyFilter(
      _metadata,
      favouriteTypes,
      _filter,
    );
    final bool showWordFilter = _metadata.any(
      (metadata) => metadata.category == PuzzleCategory.word,
    );

    if (_isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          PuzzleCardShimmer(),
          SizedBox(height: 16),
          PuzzleCardShimmer(),
          SizedBox(height: 16),
          PuzzleCardShimmer(),
        ],
      );
    }

    if (_metadata.isEmpty) {
      return AppEmptyState(
        icon: Icons.extension_outlined,
        title: 'No Puzzles Available',
        message:
            'No puzzle engines are currently registered. Please check your configuration.',
        action: ElevatedButton.icon(
          onPressed: _loadPuzzles,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const SectionHeader(
          title: 'Puzzle Library',
          subtitle:
              'Choose a puzzle type, then pick Daily Challenge or Random Play.',
        ),
        const SizedBox(height: 20),
        FilterChipRow<PuzzleLibraryFilter>(
          selectedValue: _filter,
          onSelected: (filter) => setState(() => _filter = filter),
          options: <FilterChipOption<PuzzleLibraryFilter>>[
            const FilterChipOption(
              value: PuzzleLibraryFilter.all,
              label: 'All',
            ),
            const FilterChipOption(
              value: PuzzleLibraryFilter.numbers,
              label: 'Numbers',
            ),
            const FilterChipOption(
              value: PuzzleLibraryFilter.visual,
              label: 'Visual',
            ),
            const FilterChipOption(
              value: PuzzleLibraryFilter.favourites,
              label: 'Favourites',
            ),
            if (showWordFilter)
              const FilterChipOption(
                value: PuzzleLibraryFilter.word,
                label: 'Word',
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          EmptyStateCard(
            title: _filter == PuzzleLibraryFilter.favourites
                ? 'No favourite puzzles yet'
                : 'No puzzle types match this filter',
            body: _filter == PuzzleLibraryFilter.favourites
                ? 'Star a puzzle card to save that puzzle type here.'
                : 'Try All, Numbers, or Visual to browse the available puzzle types.',
            icon: _filter == PuzzleLibraryFilter.favourites
                ? Icons.star_outline
                : Icons.filter_list_off,
          )
        else
          ...filtered.map(
            (metadata) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PuzzleLibraryCardItem(metadata: metadata),
            ),
          ),
      ],
    );
  }
}

class _PuzzleLibraryCardItem extends ConsumerWidget {
  const _PuzzleLibraryCardItem({required this.metadata});

  final PuzzleMetadata metadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFavourite =
        ref.watch(isFavouritePuzzleTypeProvider(metadata.type)).asData?.value ??
        false;
    final ActivePuzzleRun? activeRun = ref
        .watch(activeRunForPuzzleTypeProvider(metadata.type))
        .asData
        ?.value;

    return PuzzleCard(
      metadata: metadata,
      isFavourite: isFavourite,
      isInProgress: activeRun != null,
      onTap: metadata.isAvailable
          ? () => showPuzzleDetailSheet(context: context, metadata: metadata)
          : null,
      onToggleFavourite: () =>
          ref.read(favouritePuzzleControllerProvider).toggle(metadata.type),
      onResume: activeRun == null || !metadata.isAvailable
          ? null
          : () => resumePuzzleRun(
              context: context,
              ref: ref,
              puzzleType: metadata.type,
            ),
    );
  }
}

enum PuzzleLibraryFilter { all, numbers, visual, word, favourites }

List<PuzzleMetadata> _applyFilter(
  List<PuzzleMetadata> metadata,
  Set<PuzzleType> favouriteTypes,
  PuzzleLibraryFilter filter,
) {
  return metadata.where((item) {
    switch (filter) {
      case PuzzleLibraryFilter.all:
        return true;
      case PuzzleLibraryFilter.numbers:
        return _isNumbersPuzzle(item.type);
      case PuzzleLibraryFilter.visual:
        return _isVisualPuzzle(item.type);
      case PuzzleLibraryFilter.word:
        return item.category == PuzzleCategory.word;
      case PuzzleLibraryFilter.favourites:
        return favouriteTypes.contains(item.type);
    }
  }).toList();
}

bool _isNumbersPuzzle(PuzzleType type) {
  switch (type) {
    case PuzzleType.sudokuClassic:
    case PuzzleType.kakuroClassic:
    case PuzzleType.mathdokuClassic:
    case PuzzleType.takuzuBinary:
      return true;
    case PuzzleType.nonogramMono:
    case PuzzleType.slitherlinkLoop:
    case PuzzleType.killerQueens:
      return false;
  }
}

bool _isVisualPuzzle(PuzzleType type) {
  switch (type) {
    case PuzzleType.nonogramMono:
    case PuzzleType.slitherlinkLoop:
    case PuzzleType.killerQueens:
      return true;
    case PuzzleType.sudokuClassic:
    case PuzzleType.kakuroClassic:
    case PuzzleType.mathdokuClassic:
    case PuzzleType.takuzuBinary:
      return false;
  }
}

int _librarySortKey(PuzzleType type) {
  switch (type) {
    case PuzzleType.sudokuClassic:
      return 0;
    case PuzzleType.mathdokuClassic:
      return 1;
    case PuzzleType.takuzuBinary:
      return 2;
    case PuzzleType.nonogramMono:
      return 10;
    case PuzzleType.slitherlinkLoop:
      return 11;
    case PuzzleType.killerQueens:
      return 12;
    case PuzzleType.kakuroClassic:
      return 99;
  }
}
