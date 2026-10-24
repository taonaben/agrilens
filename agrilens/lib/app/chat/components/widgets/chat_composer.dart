import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:solar_icons/solar_icons.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          border: Border(top: BorderSide(color: AppColors.border(brightness))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isBusy,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!isBusy) {
                    onSend();
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Ask a follow-up question...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const Gap(AppConstants.gapSmall),
            IconButton.filled(
              onPressed: isBusy ? null : onSend,
              icon: const Icon(SolarIconsOutline.arrowRight),
              tooltip: 'Send message',
            ),
          ],
        ),
      ),
    );
  }
}
