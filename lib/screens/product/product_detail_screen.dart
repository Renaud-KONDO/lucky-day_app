import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../data/models/models.dart';
import '../../providers/raffle_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../raffle/raffle_detail_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0;
  List<Raffle> _activeRaffles = [];
  bool _loadingRaffles = true;

  @override
  void initState() {
    super.initState();
    _loadActiveRaffles();
  }

  Future<void> _loadActiveRaffles() async {
    setState(() => _loadingRaffles = true);
    try {
      // Récupère toutes les raffles actives pour ce produit
      final allRaffles = context.read<RaffleProvider>().allRaffles;
      _activeRaffles = allRaffles
          .where((r) => r.product?.id == widget.product.id && r.canParticipate)
          .toList();
    } catch (e) {
      print('❌ Error loading raffles: $e');
    }
    setState(() => _loadingRaffles = false);
  }

  void _showImageGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageGalleryScreen(
          images: widget.product.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = widget.product.imageUrls.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar avec images ────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: hasImages
                  ? Stack(children: [
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 300,
                          viewportFraction: 1.0,
                          enableInfiniteScroll: widget.product.imageUrls.length > 1,
                          onPageChanged: (index, _) =>
                              setState(() => _currentImageIndex = index),
                        ),
                        items: widget.product.imageUrls.map((url) {
                          return GestureDetector(
                            onTap: () => _showImageGallery(
                                widget.product.imageUrls.indexOf(url)),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, size: 64),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // Indicateur de page
                      if (widget.product.imageUrls.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: widget.product.imageUrls
                                .asMap()
                                .entries
                                .map((entry) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == entry.key
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ])
                  : Container(
                      color: const Color(0xFFEFF6FF),
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 80, color: AppTheme.primaryColor),
                    ),
            ),
          ),

          // ── Contenu ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom et prix
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.product.price.toStringAsFixed(0)} ${AppStrings.currency}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Badge disponibilité
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.product.isActive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.product.isActive
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        widget.product.isActive
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 16,
                        color: widget.product.isActive
                            ? Colors.green
                            : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.product.isActive ? 'Disponible' : 'Indisponible',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.product.isActive
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ]),
                  ),

                  // Description
                  if (widget.product.description != null &&
                      widget.product.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Description',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      widget.product.description!,
                      style: AppTheme.bodyText,
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── Tombolas actives ──────────────────────────────────
                  Row(children: [
                    const Icon(Icons.confirmation_number_outlined,
                        size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Text('Tombolas actives',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (!_loadingRaffles)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_activeRaffles.length}',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),

                  if (_loadingRaffles)
                    const Center(child: CircularProgressIndicator())
                  else if (_activeRaffles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: const Center(
                        child: Column(children: [
                          Icon(Icons.inbox, size: 48, color: AppTheme.textSecondary),
                          SizedBox(height: 8),
                          Text('Aucune tombola active pour ce produit',
                              style: AppTheme.bodyText,
                              textAlign: TextAlign.center),
                        ]),
                      ),
                    )
                  else
                    ..._activeRaffles.map((raffle) => _RaffleCard(
                          raffle: raffle,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RaffleDetailScreen(raffle: raffle),
                            ),
                          ),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card tombola simplifiée ──────────────────────────────────────────────────
class _RaffleCard extends StatelessWidget {
  final Raffle raffle;
  final VoidCallback onTap;

  const _RaffleCard({required this.raffle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre et badge probabilité
              Row(children: [
                Expanded(
                  child: Text(
                    raffle.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.getProbabilityColor(raffle.probabilityType)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    raffle.probabilityType == 'high'
                        ? '⭐ Forte'
                        : raffle.probabilityType == 'medium'
                            ? '🎯 Moyenne'
                            : '🎲 Faible',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          AppTheme.getProbabilityColor(raffle.probabilityType),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),

              // Prix et participants
              Row(children: [
                const Icon(Icons.payments_outlined,
                    size: 16, color: AppTheme.secondaryColor),
                const SizedBox(width: 6),
                Text(
                  '${raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.people_outline,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${raffle.currentParticipants}/${raffle.maxParticipants}',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ]),
              const SizedBox(height: 8),

              // Barre de progression
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: raffle.fillPercentage,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(
                      AppTheme.getProbabilityColor(raffle.probabilityType)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Galerie d'images plein écran ────────────────────────────────────────────
class _ImageGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageGalleryScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<_ImageGalleryScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${_currentIndex + 1}/${widget.images.length}',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: CarouselSlider(
        options: CarouselOptions(
          height: double.infinity,
          viewportFraction: 1.0,
          initialPage: widget.initialIndex,
          enableInfiniteScroll: false,
          onPageChanged: (index, _) => setState(() => _currentIndex = index),
        ),
        items: widget.images.map((url) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 80,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}