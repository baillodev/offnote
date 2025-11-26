import 'package:flutter/material.dart';

class ConnectivityIndicator extends StatelessWidget {
  final bool isOnline;
  final double iconSize;
  final TextStyle? textStyle;

  const ConnectivityIndicator({
    super.key,
    required this.isOnline,
    this.iconSize = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOnline ? Icons.wifi : Icons.wifi_off,
          color: isOnline ? Colors.green : Colors.orange,
          size: iconSize,
        ),
        const SizedBox(width: 4),
        Text(
          isOnline ? 'Online' : 'Offline',
          style:
              textStyle ??
              TextStyle(
                fontSize: 12,
                color: isOnline ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
