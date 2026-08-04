import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/app_nav_menu_button.dart';
import '../widgets/debug_screen_tag.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final _apiService = ApiService();
  String? _loadingProduct;

  Future<void> _buy(String product) async {
    setState(() => _loadingProduct = product);
    try {
      final checkoutUrl = await _apiService.createCheckoutSession(product: product);
      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open checkout page.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingProduct = null);
    }
  }

  Widget _productCard({
    required String product,
    required String title,
    required String priceLabel,
    required String description,
  }) {
    final isLoading = _loadingProduct == product;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : ElevatedButton(
          onPressed: () => _buy(product),
          child: Text(priceLabel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const DebugScreenTag('credits_screen.dart'),
      appBar: AppBar(
        title: const Text('Buy Credits'),
        actions: [const AppNavMenuButton(), const SizedBox(width: 8)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _productCard(
            product: 'TopupSmall',
            title: 'Small Top-up',
            priceLabel: '\$10',
            description: '100 credits',
          ),
          _productCard(
            product: 'TopupMedium',
            title: 'Medium Top-up',
            priceLabel: '\$20',
            description: '220 credits',
          ),
          _productCard(
            product: 'TopupLarge',
            title: 'Large Top-up',
            priceLabel: '\$30',
            description: '350 credits',
          ),
        ],
      ),
    );
  }
}
