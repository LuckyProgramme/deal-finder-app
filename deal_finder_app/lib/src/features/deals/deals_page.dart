import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../data/carousell/carousell_service.dart';
import '../../design_system/terra_theme.dart';
import '../../domain/models/audit.dart';
import '../../domain/models/deal.dart';
import '../shell/shared_widgets.dart';

enum DealFilter { current, visible, favorites, dismissed }

class DealsPage extends ConsumerStatefulWidget {
  const DealsPage({super.key});
  @override
  ConsumerState<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends ConsumerState<DealsPage> {
  String query = '', category = 'All categories';
  DealFilter filter = DealFilter.current;
  Future<void> flag(Deal deal, {bool? favorite, bool? dismissed}) async {
    try {
      await ref
          .read(dealRepositoryProvider)
          .setDealFlags(deal.id, favorite: favorite, dismissed: dismissed);
      if (mounted && dismissed != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dismissed ? 'Deal dismissed' : 'Deal restored'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await ref
                      .read(dealRepositoryProvider)
                      .setDealFlags(deal.id, dismissed: deal.isDismissed);
                } catch (_) {
                  if (mounted) {
                    showMessage(context, 'Could not undo this change.');
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Your change could not be saved. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deals = ref.watch(
      // Both filters hide dismissals; the repository stream defines scope:
      // latest committed snapshot versus the complete saved history.
      filter == DealFilter.current ? currentDealsProvider : dealsProvider,
    );
    final categories = {
      'All categories',
      ...?deals.asData?.value.map((d) => d.target.category),
    };
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const PageStorageKey('deals-scroll'),
        padding: EdgeInsets.all(
          constraints.maxWidth >= Terra.shellBreakpoint
              ? Terra.desktopMargin
              : Terra.mobileMargin,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Terra.contentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Good finds, just for you',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'A little patience. A better price. Your next find is here.',
                ),
                const SizedBox(height: 24),
                const TerraBadge(
                  'Saved on this device • available offline',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search deals, devices, or sellers',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .map(
                        (c) => ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          onSelected: (_) => setState(() => category = c),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DealFilter.values
                      .map(
                        (f) => ChoiceChip(
                          label: Text(switch (f) {
                            DealFilter.current => 'Latest scan',
                            DealFilter.visible => 'All saved finds',
                            DealFilter.favorites => 'Favorites',
                            DealFilter.dismissed => 'Dismissed',
                          }),
                          selected: filter == f,
                          onSelected: (_) => setState(() => filter = f),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                deals.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading deals',
                    ),
                  ),
                  error: (_, _) => NoticeCard(
                    title: 'Your finds need a moment',
                    message: 'We couldn’t read the local deals library.',
                    action: OutlinedButton(
                      onPressed: () {
                        ref.invalidate(currentDealsProvider);
                        ref.invalidate(dealsProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ),
                  data: (items) {
                    final visible = items
                        .where(
                          (d) => switch (filter) {
                            DealFilter.current => !d.isDismissed,
                            DealFilter.visible => !d.isDismissed,
                            DealFilter.favorites =>
                              d.isFavorite && !d.isDismissed,
                            DealFilter.dismissed => d.isDismissed,
                          },
                        )
                        .where(
                          (d) =>
                              category == 'All categories' ||
                              d.target.category == category,
                        )
                        .where(
                          (d) =>
                              '${d.listing.title} ${d.target.name} ${d.listing.seller}'
                                  .toLowerCase()
                                  .contains(query),
                        )
                        .toList();
                    if (visible.isEmpty) {
                      return NoticeCard(
                        title: items.isEmpty
                            ? 'Your next find is taking root'
                            : 'No finds match these filters',
                        message: items.isEmpty
                            ? 'Add a target and start a scan. Verified deals will be waiting here when it finishes.'
                            : 'Try another search, category, or saved view.',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${visible.length} finds • sorted by savings against your target',
                          style: const TextStyle(color: Terra.muted),
                        ),
                        const SizedBox(height: 16),
                        FlowCards(
                          children: visible
                              .map(
                                (deal) => DealCard(
                                  deal: deal,
                                  onFavorite: () =>
                                      flag(deal, favorite: !deal.isFavorite),
                                  onDismiss: () =>
                                      flag(deal, dismissed: !deal.isDismissed),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openListing(BuildContext context, String link) async {
  if (!validCarousellUrl(link)) {
    showMessage(
      context,
      'This listing link is not a valid HTTPS Carousell link.',
    );
    return;
  }
  try {
    final opened = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      showMessage(context, 'No browser could open this listing.');
    }
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Could not open the listing. Please retry.');
    }
  }
}

class DealCard extends StatelessWidget {
  const DealCard({
    super.key,
    required this.deal,
    required this.onFavorite,
    required this.onDismiss,
  });
  final Deal deal;
  final VoidCallback onFavorite, onDismiss;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            AspectRatio(aspectRatio: 1.65, child: DealThumbnail(deal: deal)),
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: Terra.surface,
                borderRadius: BorderRadius.circular(24),
                child: IconButton(
                  tooltip: deal.isFavorite
                      ? 'Unfavorite ${deal.listing.title}'
                      : 'Favorite ${deal.listing.title}',
                  onPressed: onFavorite,
                  icon: Icon(
                    deal.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Terra.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                deal.target.category,
                style: const TextStyle(
                  color: Terra.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                deal.listing.title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                deal.price.formatted,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Terra.ink,
                ),
              ),
              Text(
                'Your target ${deal.target.dealPrice.formatted}',
                style: const TextStyle(color: Terra.muted),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TerraBadge(
                  'Save ${deal.savings.formatted}',
                  color: Terra.savings,
                ),
              ),
              const SizedBox(height: 16),
              TerraBadge(
                deal.provenance.label,
                color: deal.provenance is GeminiProvenance
                    ? Terra.primary
                    : Terra.warning,
                icon: deal.provenance is GeminiProvenance
                    ? Icons.verified_outlined
                    : Icons.manage_search,
              ),
              const SizedBox(height: 12),
              Text(
                deal.finalCondition.isEmpty
                    ? 'Condition not provided'
                    : deal.finalCondition,
              ),
              if (deal.listing.location != null)
                Text(
                  deal.listing.location!,
                  style: const TextStyle(color: Terra.muted),
                ),
              if (deal.issues.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  deal.issues.join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Terra.warning),
                ),
              ],
              if (deal.freebies.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Includes: ${deal.freebies.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DealDetails(deal: deal),
                ),
                icon: const Icon(Icons.info_outline),
                label: const Text('View details'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => openListing(context, deal.listing.link),
                icon: const Icon(Icons.open_in_new),
                label: const Text('View on Carousell'),
              ),
              TextButton.icon(
                onPressed: onDismiss,
                icon: Icon(
                  deal.isDismissed
                      ? Icons.restore
                      : Icons.visibility_off_outlined,
                ),
                label: Text(deal.isDismissed ? 'Restore deal' : 'Dismiss'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DealThumbnail extends StatelessWidget {
  const DealThumbnail({super.key, required this.deal});
  final Deal deal;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(deal.listing.thumbnailUrl ?? '');
    final placeholder = ColoredBox(
      color: Terra.sandstone,
      child: Center(
        child: Icon(
          Icons.devices_outlined,
          size: 56,
          color: Terra.primary.withValues(alpha: .6),
          semanticLabel: 'Product image unavailable',
        ),
      ),
    );
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return placeholder;
    }
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
      cacheWidth: 700,
      semanticLabel: deal.listing.title,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

class DealDetails extends StatelessWidget {
  const DealDetails({super.key, required this.deal});
  final Deal deal;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              deal.listing.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '${deal.price.formatted} • target ${deal.target.dealPrice.formatted}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TerraBadge(deal.provenance.label),
            const SizedBox(height: 16),
            Text(switch (deal.provenance) {
              GeminiProvenance(:final confidence) =>
                'Gemini confidence: $confidence%. This is model output, not a warranty or seller verification.',
              LocalProvenance(:final score) =>
                'Local similarity: ${score.toStringAsFixed(1)}. No Gemini verification.',
            }),
            const SizedBox(height: 16),
            Text('Condition: ${deal.finalCondition}'),
            Text(
              'Seller: ${deal.listing.seller.isEmpty ? 'Not provided' : deal.listing.seller}',
            ),
            Text(
              'Rating: ${deal.listing.sellerRating?.toStringAsFixed(1) ?? 'Not provided'} • ${deal.listing.sellerRatingCount?.toString() ?? 'Unknown'} reviews',
            ),
            Text('Location: ${deal.listing.location ?? 'Not provided'}'),
            Text(
              'Listed: ${DateTime.tryParse(deal.listing.listedAt ?? '') == null ? 'Not provided' : localDate(DateTime.parse(deal.listing.listedAt!))}',
            ),
            Text('First found: ${localDate(deal.firstSeen)}'),
            Text('Last found: ${localDate(deal.lastSeen)}'),
            if (deal.isBundle) ...[
              const SizedBox(height: 16),
              const Text('Separately priced bundle item'),
              Text(
                'Original listing price: ${deal.listing.price?.formatted ?? 'Unknown'}',
              ),
              Text(deal.priceEvidence ?? ''),
            ],
            if (deal.issues.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Review notes: ${deal.issues.join('; ')}'),
            ],
            if (deal.freebies.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Freebies: ${deal.freebies.join(', ')}'),
            ],
            const SizedBox(height: 16),
            SelectableText(
              deal.listing.description.isEmpty
                  ? 'No description supplied.'
                  : deal.listing.description,
            ),
            const SizedBox(height: 24),
            const Text(
              'Confirm condition, availability, and price with the seller before buying.',
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: () => openListing(context, deal.listing.link),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open listing'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
