import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = 'https://api.instafix.io/reel/DT_Xia9AQVg/';
  print('Fetching $url...');
  try {
    final response = await http.get(Uri.parse(url));
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(json));
    }
  } catch (e) {
    print('Error: $e');
  }
}
