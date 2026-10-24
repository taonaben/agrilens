import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ChatBusyIndicator extends StatelessWidget {
  const ChatBusyIndicator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
      ),
      child: Column(
        children: [
          const LinearProgressIndicator(),
          const Gap(AppConstants.gapXSmall),
          Align(alignment: Alignment.centerLeft, child: Text(label)),
        ],
      ),
    );
  }
}
