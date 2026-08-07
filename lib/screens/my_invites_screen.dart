import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/app_strings.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';
import '../theme/theme_controller.dart';

class MyInvitesScreen extends StatefulWidget {
  const MyInvitesScreen({super.key});

  @override
  State<MyInvitesScreen> createState() => _MyInvitesScreenState();
}

class _MyInvitesScreenState extends State<MyInvitesScreen> {
  final _authService = AuthService();
  late Future<ReferralSummary> _summaryFuture;
  String? _username;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _authService.getMyReferrals();
    _authService.getUsername().then((value) {
      if (mounted) setState(() => _username = value);
    });
    AppStrings.languageCode.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppStrings.languageCode.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _summaryFuture = _authService.getMyReferrals();
    });
  }

  void _copyUsername(BuildContext context) {
    if (_username == null) return;
    final link = '${ApiService.webAppUrl}/?ref=$_username';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.t('invite_link_copied'))),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance.listenable,
      builder: (context, _) => Scaffold(
        backgroundColor: ThemeController.instance.backgroundData.color,
        bottomNavigationBar: const DebugScreenTag('my_invites_screen.dart'),
      appBar: AppBar(
        centerTitle: true,
        title: Text(AppStrings.t('my_invites_title')),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<ReferralSummary>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('${AppStrings.t('error_prefix')} ${snapshot.error}'));
            }

            final summary = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_username != null)
                  GestureDetector(
                    onTap: () => _copyUsername(context),
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.person_add_alt),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppStrings.t('tap_to_copy_invite_link'),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const Icon(Icons.copy, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          '${summary.bonusCredits}',
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.bonusCredits == 1
                              ? AppStrings.t('bonus_credit_earned_singular')
                              : AppStrings.t('bonus_credits_earned_plural'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.t('bonus_credit_explanation'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.t('friends_who_joined'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ThemeController.instance.backgroundData.titleTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                if (summary.referrals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      AppStrings.t('nobody_joined_yet'),
                      style: TextStyle(color: ThemeController.instance.backgroundData.bodyTextColor),
                    ),
                  )
                else
                  for (final referral in summary.referrals)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(referral.username),
                        subtitle: Text('${AppStrings.t('joined_prefix')} ${_formatDate(referral.joinedAt)}'),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }
}
