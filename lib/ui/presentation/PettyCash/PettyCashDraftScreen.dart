import 'package:el_race/ui/presentation/PettyCash/petty_cash_draft_summary_screen.dart';
import 'package:flutter/material.dart';

class PettyCashDraftScreen extends StatefulWidget {
  const PettyCashDraftScreen({super.key});

  @override
  State<PettyCashDraftScreen> createState() => _PettyCashDraftScreenState();
}

class _PettyCashDraftScreenState extends State<PettyCashDraftScreen> {
  @override
  Widget build(BuildContext context) {
    return const PettyCashDraftSummaryScreen(
      title: 'TRANSPORTATIONS',
      expenseType: 'fleet',
      titleIcon: Icons.local_gas_station_outlined,
    );
  }
}
