import 'package:flutter_test/flutter_test.dart';
import 'package:konex/core/deep_links/deep_link_parser.dart';
import 'package:konex/core/deep_links/deep_link_models.dart';

void main() {
  test('parses profile username path', () {
    final t = DeepLinkParser.parse(Uri.parse('https://konex-app-rho.vercel.app/u/xeron'));
    expect(t?.type, DeepLinkType.profile);
    expect(t?.username, 'xeron');
  });

  test('parses squad uuid path', () {
    final t = DeepLinkParser.parse(
      Uri.parse('https://konex-app-rho.vercel.app/squad/11111111-1111-1111-1111-111111111111'),
    );
    expect(t?.type, DeepLinkType.squad);
    expect(t?.id, '11111111-1111-1111-1111-111111111111');
  });

  test('rejects foreign hosts', () {
    final t = DeepLinkParser.parse(Uri.parse('https://evil.example/u/xeron'));
    expect(t, isNull);
  });
}
