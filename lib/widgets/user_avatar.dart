import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Reusable avatar widget that handles user photos from Firestore
/// Uses caching to reduce network requests and avoid rate limiting
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackUrl = "https://ui-avatars.com/api/?name=$name";
    final imageUrl = (photoUrl != null && photoUrl!.isNotEmpty) ? photoUrl! : fallbackUrl;

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          httpHeaders: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://google.com',
          },
          placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
          errorWidget: (context, url, error) {
            // Fallback to ui-avatars on error
            return Image.network(
              fallbackUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Ultimate fallback: icon
                return Icon(Icons.person, size: radius, color: Colors.grey[600]);
              },
            );
          },
        ),
      ),
    );
  }
}
