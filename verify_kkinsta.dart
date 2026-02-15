import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  final url = 'https://kkinstagram.com/reel/DT_Xia9AQVg/';
  final uri = Uri.parse(url);
  final headers = {
    'User-Agent':
        'Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)',
  };

  print('Fetching $url with Discordbot UA...');
  try {
    final response = await http.get(uri, headers: headers);
    print('Status: ${response.statusCode}');
    print('Content-Type: ${response.headers['content-type']}');
    if (response.statusCode == 200) {
      final document = parser.parse(response.body);
      final ogVideo = document
          .querySelector('meta[property="og:video"]')
          ?.attributes['content'];
      print('og:video = $ogVideo');
    }
  } catch (e) {
    print('Error: $e');
  }
}
