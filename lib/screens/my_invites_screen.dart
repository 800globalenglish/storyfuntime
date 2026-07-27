import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

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
      const SnackBar(content: Text('Invite link copied — share it with a friend!')),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Invites')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<ReferralSummary>(
          future: _summaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
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
                                'Tap to copy your invite link',
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
                          summary.bonusCredits == 1 ? 'Bonus Story Credit Earned' : 'Bonus Story Credits Earned',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Earn 1 bonus credit for every friend who joins using your invite.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Friends Who Joined', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (summary.referrals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Nobody has joined using your invite yet — share your username to get started!'),
                  )
                else
                  for (final referral in summary.referrals)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(referral.username),
                        subtitle: Text('Joined ${_formatDate(referral.joinedAt)}'),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
