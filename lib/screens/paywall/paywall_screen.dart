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
                const SizedBox(height: 24),
                const Icon(Icons.workspace_premium_rounded, size: 48, color: appAccent),
                const SizedBox(height: 16),
                Text(
                  'Free Limit Reached',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'We are so sorry you have to see this! 🙈\nBut updating and keeping this app alive with new features is time consuming. The money is only needed to support the dev and his team to keep your favorite app alive.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: appTextMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
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
                        const SizedBox(height: 12),
                        _buildChoiceCard(
                          title: 'Buy 400 Scans',
                          subtitle: 'More than enough for an average year! No subs.',
                          price: monetization.premiumProduct?.price ?? '\$1.99',
                          icon: Icons.receipt_long,
                          color: appSurface,
                          borderColor: appLine,
                          onTap: monetization.isLoading
                              ? null
                              : () async {
                                  await monetization.purchasePremium();
                                },
                        ),
                        const SizedBox(height: 12),
                        _buildChoiceCard(
                          title: '1-Year VIP',
                          subtitle: 'Buy the dev team a coffee and enjoy absolute freedom. ❤️',
                          price: monetization.isHalfPrice 
                              ? '\$5.00/yr' 
                              : (monetization.yearlyProduct?.price ?? '\$10.00/yr'),
                          icon: Icons.star_rounded,
                          color: appAccent.withOpacity(0.1),
                          borderColor: appAccent,
                          textColor: appAccent,
                          isHighlight: true,
                          onTap: monetization.isLoading
                              ? null
                              : () async {
                                  await monetization.purchaseYearly();
                                  if (context.mounted && monetization.isPremium) {
                                    Navigator.pop(context);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          _showPromoDialog(context, monetization);
                        },
                        child: Text(
                          'Promo Code',
                          style: GoogleFonts.inter(color: appTextMuted, fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          'Maybe later',
                          style: GoogleFonts.inter(color: appTextMuted, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPromoDialog(BuildContext context, MonetizationProvider monetization) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: appSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Redeem Code', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter promo code',
              hintStyle: TextStyle(color: appTextMuted.withOpacity(0.5)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: appLine)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: appAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: appTextMuted)),
            ),
            TextButton(
              onPressed: () async {
                final success = await monetization.redeemPromoCode(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Promo code applied!', style: GoogleFonts.inter()), backgroundColor: appAccent),
                    );
                    if (monetization.isPremium) {
                      Navigator.pop(context); // Close paywall if unlocked
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invalid code.', style: GoogleFonts.inter()), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text('Redeem', style: GoogleFonts.inter(color: appAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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
    bool isHighlight = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isHighlight ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: textColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isHighlight ? textColor.withOpacity(0.8) : appTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
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
