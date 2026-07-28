import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/monetization_provider.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: Consumer<MonetizationProvider>(
          builder: (context, monetization, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.workspace_premium_rounded, size: 64, color: appAccent),
                const SizedBox(height: 24),
                Text(
                  'Free Limit Reached',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have used all 100 free scans.\nChoose how you want to continue.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: appTextMuted,
                  ),
                ),
                const SizedBox(height: 48),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        _buildChoiceCard(
                          title: 'Ad-Supported',
                          subtitle: 'Unlimited scans, forever.',
                          price: 'Free',
                          icon: Icons.ads_click,
                          color: appSurface,
                          borderColor: appLine,
                          onTap: () async {
                            await monetization.chooseAdSupportedTier();
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildChoiceCard(
                          title: 'Buy 400 Scans',
                          subtitle: 'No subscriptions. Ad-free.',
                          price: monetization.premiumProduct?.price ?? '\$1.99',
                          icon: Icons.receipt_long,
                          color: appAccent.withOpacity(0.1),
                          borderColor: appAccent,
                          textColor: appAccent,
                          onTap: monetization.isLoading
                              ? null
                              : () async {
                                  await monetization.purchasePremium();
                                  // Navigating back is handled by purchase stream listener or user manually returning
                                  // But we can pop optimistically if you prefer, or just wait for the user.
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: TextButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'Maybe later',
                      style: GoogleFonts.inter(color: appTextMuted, fontSize: 16),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required Color color,
    required Color borderColor,
    Color textColor = Colors.white,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: appTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
