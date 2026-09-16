import 'package:arus_finance/features/home/home_greeting_insight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home greeting follows local daypart and optional local profile name', () {
    expect(homeGreetingFor(DateTime(2026, 9, 16, 8)), 'Selamat pagi');
    expect(
      homeGreetingFor(DateTime(2026, 9, 16, 8), name: 'Ema'),
      'Selamat pagi, Ema',
    );
    expect(
      homeGreetingFor(DateTime(2026, 9, 16, 13), name: 'Ema'),
      'Selamat siang, Ema',
    );
    expect(
      homeGreetingFor(DateTime(2026, 9, 16, 16), name: 'Ema'),
      'Selamat sore, Ema',
    );
    expect(
      homeGreetingFor(DateTime(2026, 9, 16, 20), name: 'Ema'),
      'Selamat malam, Ema',
    );
    expect(
      homeGreetingFor(DateTime(2026, 9, 16, 8), name: '   '),
      'Selamat pagi',
    );
  });
}
