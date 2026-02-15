import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final id = 'DT_Xia9AQVg';
  final url = 'https://api.kkinstagram.com/videos/$id';

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
