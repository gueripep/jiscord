import 'package:http/http.dart' as http;

void main() async {
  final id = 'DT_Xia9AQVg';
  final url = 'https://www.kkinstagram.com/thumbnail/$id/';

  print('Fetching $url...');
  try {
    final response = await http.get(Uri.parse(url));
    print('Status: ${response.statusCode}');
    print('Content-Type: ${response.headers['content-type']}');
  } catch (e) {
    print('Error: $e');
  }
}
