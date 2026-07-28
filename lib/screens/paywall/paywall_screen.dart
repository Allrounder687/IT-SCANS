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
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.document_scanner_rounded, size: 80, color: appAccent),
                          const SizedBox(height: 32),
                          Text(
                            'Scan Limit Reached',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'You have used all your free scans. Unlock unlimited scanning forever with a one-time purchase.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: appTextMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            monetization.premiumProduct?.price ?? '\$2.00',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appAccent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 64),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: monetization.isLoading || monetization.isPremium
                            ? null
                            : () async {
                                await monetization.purchasePremium();
                                if (context.mounted && monetization.isPremium) {
                                  Navigator.pop(context);
                                }
                              },
                        child: Text(
                          'Unlock Unlimited Scans',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          monetization.restorePurchases();
                        },
                        child: Text(
                          'Restore purchases',
                          style: GoogleFonts.inter(color: appTextMuted, fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Not now',
                          style: GoogleFonts.inter(color: appTextMuted, fontSize: 16),
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
}
