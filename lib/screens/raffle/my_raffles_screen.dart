/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/raffle_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/raffle_card.dart';

class MyRafflesScreen extends StatefulWidget {
  const MyRafflesScreen({super.key});
  @override
  State<MyRafflesScreen> createState() => _MyRafflesScreenState();
}

class _MyRafflesScreenState extends State<MyRafflesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<RaffleProvider>();
      p.fetchMine();
      p.fetchWins();
    });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Tombolas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final p = context.read<RaffleProvider>();
              p.fetchMine(); p.fetchWins();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'En cours'), Tab(text: '🏆 Gagnées')],
        ),
      ),
      body: Consumer<RaffleProvider>(
        builder: (_, prov, __) => TabBarView(
          controller: _tab,
          children: [
            _buildList(prov.myRaffles, false, () => prov.fetchMine(),
              empty: 'Aucune participation en cours'),
            _buildList(prov.myWins, true, () => prov.fetchWins(),
              empty: "Vous n'avez encore rien gagné\nBonne chance !"),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List raffles, bool isWon, Future<void> Function() onRefresh, {required String empty}) {
    if (raffles.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isWon ? Icons.emoji_events : Icons.inbox, size: 64, color: AppTheme.textSecondary),
        const SizedBox(height: 12),
        Text(empty, style: AppTheme.bodyText, textAlign: TextAlign.center),
      ]));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: raffles.length,
        itemBuilder: (_, i) => RaffleCard(raffle: raffles[i], isWon: isWon, onTap: () {}),
      ),
    );
  }
}
 */


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/raffle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/raffle_card.dart';
import '../../data/models/models.dart';

class MyRafflesScreen extends StatefulWidget {
  const MyRafflesScreen({super.key});
  @override
  State<MyRafflesScreen> createState() => _MyRafflesScreenState();
}

class _MyRafflesScreenState extends State<MyRafflesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<RaffleProvider>();
      p.fetchMine();
      p.fetchWins();
    });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Tombolas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final p = context.read<RaffleProvider>();
              p.fetchMine();
              p.fetchWins();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.accentColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Participations'),
            Tab(text: '🏆 Gagnées'),
          ],
        ),
      ),
      body: Consumer<RaffleProvider>(
        builder: (_, prov, __) => TabBarView(
          controller: _tab,
          children: [
            _ParticipationsTab(raffles: prov.myRaffles, onRefresh: prov.fetchMine),
            _WinsTab(raffles: prov.myWins, onRefresh: prov.fetchWins),
          ],
        ),
      ),
    );
  }
}

// ─── Toutes les participations ────────────────────────────────────────────────
class _ParticipationsTab extends StatelessWidget {
  final List<Raffle> raffles;
  final Future<void> Function() onRefresh;
  const _ParticipationsTab({required this.raffles, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (raffles.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text('Aucune participation', style: AppTheme.bodyText),
          SizedBox(height: 6),
          Text('Participez à des tombolas pour les voir ici',
              style: AppTheme.caption, textAlign: TextAlign.center),
        ],
      ));
    }

    // Grouper par statut
    final open      = raffles.where((r) => r.status == 'open' || r.status == 'full').toList();
    final lost      = raffles.where((r) => r.status == 'drawn' && r.winnerId != null).toList();
    final cancelled = raffles.where((r) => r.status == 'cancelled').toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (open.isNotEmpty) ...[
            _sectionTitle('En cours (${open.length})', AppTheme.primaryColor),
            ...open.map((r) => RaffleCard(raffle: r, onTap: () {})),
          ],
          if (lost.isNotEmpty) ...[
            _sectionTitle('Perdues (${lost.length})', AppTheme.textSecondary),
            ...lost.map((r) => RaffleCard(raffle: r, onTap: () {},
                label: 'PERDU', labelColor: Colors.grey)),
          ],
          if (cancelled.isNotEmpty) ...[
            _sectionTitle('Annulées (${cancelled.length})', Colors.orange),
            ...cancelled.map((r) => RaffleCard(raffle: r, onTap: () {},
                label: 'ANNULÉ', labelColor: Colors.orange)),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
    child: Text(t, style: TextStyle(
        fontWeight: FontWeight.bold, color: color, fontSize: 13)),
  );
}

// ─── Tombolas gagnées ─────────────────────────────────────────────────────────
class _WinsTab extends StatelessWidget {
  final List<Raffle> raffles;
  final Future<void> Function() onRefresh;
  const _WinsTab({required this.raffles, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (raffles.isEmpty) {
      return const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text("Vous n'avez encore rien gagné", style: AppTheme.bodyText),
          SizedBox(height: 6),
          Text('Bonne chance pour vos prochaines tombolas !',
              style: AppTheme.caption, textAlign: TextAlign.center),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: raffles.length,
        itemBuilder: (_, i) {
          final r = raffles[i];
          final claimed = r.status == 'claimed';
          return Column(children: [
            RaffleCard(raffle: r, isWon: true, onTap: () {}),
            if (!claimed)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: ElevatedButton.icon(
                  onPressed: () => _openClaimSheet(context, r),
                  icon: const Icon(Icons.redeem, size: 18),
                  label: const Text('Réclamer mon prix'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Réclamation en cours de traitement',
                          style: TextStyle(color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }

  void _openClaimSheet(BuildContext context, Raffle raffle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ClaimSheet(raffle: raffle),
    );
  }
}

// ─── Bottom Sheet Claim ───────────────────────────────────────────────────────
class _ClaimSheet extends StatefulWidget {
  final Raffle raffle;
  const _ClaimSheet({required this.raffle});
  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  String? _option;          // 'cash' ou 'delivery'
  bool _useCurrentLocation = true;
  final _addressCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() { _addressCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_option == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une option')));
      return;
    }
    if (_option == 'delivery' && !_useCurrentLocation
        && _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une adresse')));
      return;
    }

    setState(() => _submitting = true);
    final prov = context.read<RaffleProvider>();

    Map<String, dynamic>? deliveryAddress;
    if (_option == 'delivery') {
      deliveryAddress = {
        'address': _useCurrentLocation
            ? 'Position actuelle'
            : _addressCtrl.text.trim(),
        'useCurrentLocation': _useCurrentLocation,
      };
    }

    final ok = await prov.claimPrize(
      raffleId: widget.raffle.id,
      claimOption: _option!,
      deliveryAddress: deliveryAddress,
    );

    setState(() => _submitting = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? '🎉 Réclamation soumise ! En cours de traitement.'
            : prov.errorMessage ?? 'Erreur'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),

          // Titre
          Row(children: [
            const Icon(Icons.emoji_events, color: AppTheme.secondaryColor),
            const SizedBox(width: 10),
            const Text('Réclamer votre prix',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(widget.raffle.title,
              style: AppTheme.bodyText,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),

          // ── Option Cash (si dispo) ──────────────────────────────────────
          if (widget.raffle.cashOptionAvailable) ...[
            _optionCard(
              value: 'cash',
              icon: Icons.payments_outlined,
              title: 'Encaisser le montant',
              subtitle: '${widget.raffle.cashAmount?.toStringAsFixed(0) ?? "—"} ${AppStrings.currency} '
                  'crédités sur votre portefeuille',
              color: AppTheme.secondaryColor,
            ),
            const SizedBox(height: 12),
          ],

          // ── Option Livraison ────────────────────────────────────────────
          _optionCard(
            value: 'delivery',
            icon: Icons.local_shipping_outlined,
            title: 'Recevoir le produit',
            subtitle: 'Le produit vous sera livré à votre adresse',
            color: AppTheme.primaryColor,
          ),

          // ── Adresse (si livraison choisie) ──────────────────────────────
          if (_option == 'delivery') ...[
            const SizedBox(height: 20),
            const Text('Adresse de livraison',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 10),

            // Toggle position actuelle / autre adresse
            Row(children: [
              Expanded(
                child: _locationChoice(
                  icon: Icons.my_location,
                  label: 'Ma position actuelle',
                  selected: _useCurrentLocation,
                  onTap: () => setState(() => _useCurrentLocation = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _locationChoice(
                  icon: Icons.edit_location_alt_outlined,
                  label: 'Autre adresse',
                  selected: !_useCurrentLocation,
                  onTap: () => setState(() => _useCurrentLocation = false),
                ),
              ),
            ]),

            if (!_useCurrentLocation) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Adresse complète',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  hintText: 'Ex: 123 Rue de la Paix, Lomé, Togo',
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Votre position GPS sera utilisée pour la livraison.',
                    style: TextStyle(fontSize: 12,
                        color: AppTheme.primaryColor),
                  )),
                ]),
              ),
            ],
          ],

          const SizedBox(height: 24),

          // ── Bouton soumettre ────────────────────────────────────────────
          ElevatedButton(
            onPressed: (_option == null || _submitting) ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor),
            child: _submitting
                ? const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Confirmer la réclamation',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _optionCard({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final selected = _option == value;
    return GestureDetector(
      onTap: () => setState(() => _option = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.grey.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: selected ? color : AppTheme.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? color : AppTheme.textPrimary)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          )),
          if (selected)
            Icon(Icons.check_circle, color: color, size: 22),
        ]),
      ),
    );
  }

  Widget _locationChoice({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : Colors.grey.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              color: selected
                  ? AppTheme.primaryColor
                  : AppTheme.textSecondary,
              size: 22),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}