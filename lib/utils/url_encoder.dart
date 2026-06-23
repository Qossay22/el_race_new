class UrlEncoder {
  /// Encodes URLs to handle spaces and special characters
  /// This is particularly useful for S3 URLs with spaces in filenames
  static String encode(String url) {
    if (url.isEmpty) return url;
    
    try {
      // Parse the URL
      Uri uri = Uri.parse(url);
      
      // Encode each path segment separately to handle spaces and special characters
      List<String> encodedSegments = uri.pathSegments.map((segment) {
        return Uri.encodeComponent(segment);
      }).toList();
      
      // Reconstruct the path
      String encodedPath = '/${encodedSegments.join('/')}';
      
      // Reconstruct the full URL
      String encodedUrl = '${uri.scheme}://${uri.host}$encodedPath';
      
      // Add query parameters if they exist
      if (uri.query.isNotEmpty) {
        encodedUrl += '?${uri.query}';
      }
      
      return encodedUrl;
    } catch (e) {
      // If parsing fails, try simple space replacement
      return url.replaceAll(' ', '%20');
    }
  }
  
  /// Quick method to encode just spaces in URLs
  static String encodeSpaces(String url) {
    return url.replaceAll(' ', '%20');
  }
  
  /// Decode URL-encoded strings back to readable format
  static String decode(String encodedUrl) {
    try {
      return Uri.decodeFull(encodedUrl);
    } catch (e) {
      return encodedUrl;
    }
  }
} 