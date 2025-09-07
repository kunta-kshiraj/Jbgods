import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_state.dart';

class HeaderLogo extends StatelessWidget {
  final double height;
  const HeaderLogo({this.height = 88, super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          SizedBox(height: 8),
          CachedNetworkImage(
            imageUrl: logoUrl,
            height: height,
            errorWidget: (ctx, _, __) => Text(
              "JB GODS",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
            ),
            placeholder: (ctx, _) => SizedBox(height: height),
          ),
          SizedBox(height: 24),
          Divider(thickness: 1, color: Theme.of(context).dividerColor),
        ],
      ),
    );
  }
}  