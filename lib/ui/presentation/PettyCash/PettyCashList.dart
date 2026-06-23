import 'package:el_race/ui/presentation/PettyCash/petty_cash_draft_summary_screen.dart';
import 'package:flutter/material.dart';

class PettyCashList extends StatefulWidget {
  const PettyCashList({super.key});

  @override
  State<PettyCashList> createState() => _PettyCashListState();
}

class _PettyCashListState extends State<PettyCashList> {
  @override
  Widget build(BuildContext context) {
    return const PettyCashDraftSummaryScreen(
      title: 'MISCELLANEOUS',
      expenseType: 'others',
      titleIcon: Icons.format_list_bulleted_rounded,
    );
  }
}
