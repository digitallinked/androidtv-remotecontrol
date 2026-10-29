import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/features/apps/domain/name_search.dart';

void main() {
  test('name_match_rank_orders_prefix_word_contains', () {
    expect(nameMatchRank('Prime Video', 'pr'), 0);
    expect(nameMatchRank('Amazon Prime Video', 'pr'), 1);
    expect(nameMatchRank('Disney+ Hotstar', 'hot'), 1); // '+' splits words
    expect(nameMatchRank('Spotify', 'pot'), 2);
    expect(nameMatchRank('Netflix', 'ninja'), 3);
    expect(nameMatchRank('YouTube', '  YOU '), 0);
  });

  test('every_separator_starts_a_word', () {
    for (final name in [
      'A-Bc',
      'A+Bc',
      'A:Bc',
      'A&Bc',
      'A.Bc',
      'A Bc',
      'A\tBc',
    ]) {
      expect(nameMatchRank(name, 'bc'), 1, reason: name);
    }
  });

  test('a_needle_with_a_space_matches_across_words', () {
    expect(nameMatchRank('Amazon Prime Video', 'prime v'), 1);
    expect(nameMatchRank('Amazon Prime Video', 'amazon p'), 0);
    expect(nameMatchRank('Amazon Prime Video', 'rime v'), 2);
  });
}
