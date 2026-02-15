import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  final url = 'https://fxtwitter.com/i/status/2022840703064125784';
  final uri = Uri.parse(url);
  final headers = {
    'User-Agent':
        'Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)',
  };

  try {
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final document = parser.parse(response.body);
      final metas = document.querySelectorAll('meta');
      print('--- META TAGS ---');
      for (final meta in metas) {
        final property = meta.attributes['property'] ?? meta.attributes['name'];
        final content = meta.attributes['content'];
        if (property != null) {
          print('$property = $content');
        }
      }
    } else {
      print('Failed with status ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
