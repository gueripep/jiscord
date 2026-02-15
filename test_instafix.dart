import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  final url = 'https://instafix.io/reel/DT_Xia9AQVg/';
  print('Fetching $url...');
  try {
    final response = await http.get(Uri.parse(url));
    print('Status: ${response.statusCode}');
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
