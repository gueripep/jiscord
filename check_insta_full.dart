import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  final url = 'https://www.instagram.com/reel/DT_Xia9AQVg/';
  final uri = Uri.parse(url);
  final headers = {
    'User-Agent':
        'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
  };

  print('Fetching $url with Facebook external hit UA...');
  try {
    final response = await http.get(uri, headers: headers);
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final document = parser.parse(response.body);
      print('--- SEARCHING SPECIFIC TAGS ---');
      final ogVideo = document
          .querySelector('meta[property="og:video"]')
          ?.attributes['content'];
      final ogVideoSecure = document
          .querySelector('meta[property="og:video:secure_url"]')
          ?.attributes['content'];
      final ogVideoType = document
          .querySelector('meta[property="og:video:type"]')
          ?.attributes['content'];

      print('og:video = $ogVideo');
      print('og:video:secure_url = $ogVideoSecure');
      print('og:video:type = $ogVideoType');
    }
  } catch (e) {
    print('Error: $e');
  }
}
