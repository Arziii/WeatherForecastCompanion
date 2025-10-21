import 'package:flutter/material.dart';

class WeatherIconImage extends StatelessWidget {
  final String iconUrl;
  final double size;

  const WeatherIconImage({
    super.key,
    required this.iconUrl,
    this.size = 64.0,
  });

  // This helper function adds 'https:' to URLs that start with '//'
  String _formatIconUrl(String url) {
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    if (iconUrl.isEmpty) {
      // Show a placeholder if no icon URL is provided
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(
          Icons.cloud_off_outlined,
          color: Colors.white70,
        ),
      );
    }

    return Image.network(
      _formatIconUrl(iconUrl),
      width: size,
      height: size,
      fit: BoxFit.cover,
      // Show a nice loading spinner
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: Colors.white,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      // Show an error icon if the image fails to load
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: size,
          height: size,
          child: const Icon(
            Icons.cloud_off,
            color: Colors.white70,
          ),
        );
      },
    );
  }
}