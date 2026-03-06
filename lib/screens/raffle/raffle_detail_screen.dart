import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../data/models/models.dart';
import '../../providers/raffle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class RaffleDetailScreen extends StatefulWidget {
  final Raffle raffle;
  const RaffleDetailScreen({super.key, required this.raffle});

  @override
  State<RaffleDetailScreen> createState() => _RaffleDetailScreenState();
}

class _RaffleDetailScreenState extends State<RaffleDetailScreen> {
  int _currentImageIndex = 0;
  bool _isParticipating = false;
  bool _isWon = false;

  @override
  void initState() {
    super.initState();
    
    // Vérifier la participation
    final prov = context.read<RaffleProvider>();
    _isParticipating = prov.myRaffles.any((r) => r.id == widget.raffle.id);
    _isWon = prov.myWins.any((r) => r.id == widget.raffle.id);
  }

  void _showImageGallery(int initialIndex) {
    final images = widget.raffle.product?.imageUrls ?? [];
    if (images.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageGalleryScreen(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showParticipateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ParticipateSheet(raffle: widget.raffle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.raffle.product?.imageUrls ?? [];
    final hasImages = images.isNotEmpty;

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
                          enableInfiniteScroll: images.length > 1,
                          onPageChanged: (index, _) =>
                              setState(() => _currentImageIndex = index),
                        ),
                        items: images.map((url) {
                          return GestureDetector(
                            onTap: () => _showImageGallery(images.indexOf(url)),
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
                      // Indicateur
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: images.asMap().entries.map((entry) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
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
                      // Badge probabilité en overlay
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.getProbabilityColor(
                                    widget.raffle.probabilityType)
                                .withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8)
                            ],
                          ),
                          child: Text(
                            widget.raffle.probabilityType == 'high'
                                ? '⭐ Forte'
                                : widget.raffle.probabilityType == 'medium'
                                    ? '🎯 Moyenne'
                                    : '🎲 Faible',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ])
                  : Container(
                      decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradient),
                      child: const Icon(Icons.confirmation_number,
                          size: 80, color: Colors.white54),
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
                  // Titre
                  Text(
                    widget.raffle.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Prix d'entrée
                  Row(children: [
                    const Icon(Icons.confirmation_number_outlined,
                        size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    
                    Text(
                      'Mise : ${widget.raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Participants
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2)),
                    ),
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Participants',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(
                            '${widget.raffle.currentParticipants}/${widget.raffle.maxParticipants}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: widget.raffle.fillPercentage,
                          minHeight: 12,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                              AppTheme.getProbabilityColor(
                                  widget.raffle.probabilityType)),
                        ),
                      ),
                    ]),
                  ),

                  // Description
                  if (widget.raffle.description != null &&
                      widget.raffle.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Description',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(widget.raffle.description!, style: AppTheme.bodyText),
                  ],

                  // AutoDraw
                  if (widget.raffle.autoDrawEnabled) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.auto_mode,
                            size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.raffle.autoDrawType == 'instant'
                                ? 'Tirage automatique après remplissage'
                                : widget.raffle.autoDrawType == 'scheduled' &&
                                        widget.raffle.autoDrawAt != null
                                    ? 'Tirage le ${widget.raffle.autoDrawAt!.day}/${widget.raffle.autoDrawAt!.month} à ${widget.raffle.autoDrawAt!.hour}h${widget.raffle.autoDrawAt!.minute.toString().padLeft(2, '0')}'
                                    : 'Tirage automatique',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],

                  // Produit info
                  if (widget.raffle.product != null) ...[
                    const SizedBox(height: 24),
                    const Text('Prix à gagner',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.secondaryColor.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.emoji_events,
                            size: 28, color: AppTheme.secondaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.raffle.product!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              /* const SizedBox(height: 4),
                              Text(
                                'Valeur: ${widget.raffle.product!.price.toStringAsFixed(0)} ${AppStrings.currency}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.secondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ), */
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bouton participation ──────────────────────────────────────────
      /* bottomNavigationBar: widget.raffle.canParticipate
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _showParticipateSheet,
                  icon: const Icon(Icons.confirmation_number, size: 20),
                  label: Text(
                    'Participer • ${widget.raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.getProbabilityColor(
                        widget.raffle.probabilityType),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null, */
      bottomNavigationBar: !widget.raffle.canParticipate && !_isParticipating && !_isWon
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: !widget.raffle.canParticipate && _isParticipating && !_isWon
                  ? _buildLostRaffleBadge()
                  : widget.raffle.canParticipate && _isParticipating
                    ? _buildParticipatingBadge()
                    : _isParticipating && _isWon
                        ? _buildWinningBadge()
                        : _buildParticipateButton(),
              ),
          ),  
    );
  }

  Widget _buildParticipatingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.15),
            AppTheme.primaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle,
              color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Text(
            '🍀 Vous participez · Bonne chance !',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildLostRaffleBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
        const Color.fromARGB(255, 65, 65, 65).withOpacity(0.4),
        const Color.fromARGB(255, 59, 59, 59).withOpacity(0.2),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppTheme.primaryColor.withOpacity(0.3),
        width: 2,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.trending_down,
            color: AppTheme.primaryColor, size: 24),
        const SizedBox(width: 12),
        Text(
          'Tombola Perdue ! Ne perdez pas espoir 🍀',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildWinningBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Text(
            '🎉 Félicitations ! Vous avez gagné !',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipateButton() {
    return ElevatedButton(
      onPressed: () => _showParticipateSheet(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.getProbabilityColor(widget.raffle.probabilityType),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.confirmation_number, size: 24),
          const SizedBox(width: 12),
          Text(
            'Participer - ${widget.raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

}


// ─── Bottom sheet participation (réutilise depuis raffles_screen) ─────────────
class _ParticipateSheet extends StatefulWidget {
  final Raffle raffle;
  const _ParticipateSheet({required this.raffle});
  @override
  State<_ParticipateSheet> createState() => _ParticipateSheetState();
}

class _ParticipateSheetState extends State<_ParticipateSheet> {
  String _paymentMethod = 'wallet';
  bool _processing = false;

  Future<void> _participate() async {
    setState(() => _processing = true);
    final prov = context.read<RaffleProvider>();
    
    if (_paymentMethod == 'mobilemoney') {
      _paymentMethod = "mobile_money";
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement mobile money bientôt disponible'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
      setState(() => _processing = false);
      return;
    }

    final ok = await prov.participate(widget.raffle.id, _paymentMethod);
    
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        context.read<AuthProvider>().refreshProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Participation confirmée ! Bonne chance !'),
            backgroundColor: Colors.green,
          ),
        );
        // Retourne à l'écran précédent avec refresh
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(prov.errorMessage ?? 'Erreur de participation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final hasSufficientBalance =
        user != null && user.balance >= widget.raffle.entryPrice;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(
            child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        )),
        const SizedBox(height: 16),

        // Titre
        Row(children: [
          const Icon(Icons.confirmation_number, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          const Text('Participer à la tombola',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Text(widget.raffle.title,
            style: AppTheme.bodyText, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 20),

        // Prix
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prix d\'entrée',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(
                '${widget.raffle.entryPrice.toStringAsFixed(0)} ${AppStrings.currency}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Méthodes de paiement (réutilise le code de raffles_screen)
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Méthode de paiement',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ),
        const SizedBox(height: 12),

        // Wallet
        _paymentMethodCard(
          value: 'wallet',
          icon: Icons.account_balance_wallet,
          title: 'Portefeuille',
          subtitle: user != null
              ? 'Solde: ${user.balance.toStringAsFixed(0)} ${AppStrings.currency}'
              : 'Non connecté',
          available: hasSufficientBalance,
        ),
        const SizedBox(height: 10),

        // Mobile Money
        _paymentMethodCard(
          value: 'mobilemoney',
          icon: Icons.phone_android,
          title: 'Mobile Money',
          subtitle: 'T-Money, Flooz, etc.',
          available: true,
        ),

        const SizedBox(height: 24),

        // Bouton
        ElevatedButton(
          onPressed: (_processing ||
                  (_paymentMethod == 'wallet' && !hasSufficientBalance))
              ? null
              : _participate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child: _processing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Confirmer la participation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _paymentMethodCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool available,
  }) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      onTap: available ? () => setState(() => _paymentMethod = value) : null,
      child: Opacity(
        opacity: available ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor
                  : Colors.grey.withOpacity(0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: selected
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: available
                            ? AppTheme.textSecondary
                            : Colors.red)),
              ],
            )),
            if (selected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primaryColor, size: 22),
          ]),
        ),
      ),
    );
  }
}

// ─── Galerie (même que product) ───────────────────────────────────────────────
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