# frozen_string_literal: true

require 'minitest'
require 'minitest/autorun'

require_relative '../../lib/dependencies'

class SimplifyBoundsTest < Minitest::Test
  def simplify_bounds(input)
    parsed_input = input.split(',').map(&:strip).map { |bound|
      op, num = bound.split(' ').map(&:chomp)
      [ op, num.to_i ]
    }

    POECSS::Simplifier.send(:simplify_bounds, parsed_input)
  end

  def test_simplify_bounds
    assert_nil simplify_bounds('>= 25, < 25')
    assert_nil simplify_bounds('> 25, < 25')
    assert_nil simplify_bounds('> 26, < 25')
    assert_nil simplify_bounds('> 26, > 25, < 25')
    assert_nil simplify_bounds('>= 25, <= 26, = 30')
    assert_nil simplify_bounds('>= 25, < 26, = 26')

    assert_equal [ [ '=', 25 ] ], simplify_bounds('>= 25, <= 25')
    assert_equal [ [ '=', 25 ] ], simplify_bounds('>= 25, <= 26, = 25')

    assert_equal [ [ '>', 25 ] ], simplify_bounds('> 25, > 25')
    assert_equal [ [ '>', 25 ] ], simplify_bounds('> 25, > 24')
    assert_equal [ [ '>', 26 ] ], simplify_bounds('> 25, > 26')
    assert_equal [ [ '>', 25 ] ], simplify_bounds('> 25, >= 25')
    assert_equal [ [ '>', 25 ] ], simplify_bounds('>= 25, > 25')

    assert_equal [ [ '>=', 26 ] ], simplify_bounds('> 25, >= 26')
    assert_equal [ [ '>=', 28 ] ], simplify_bounds('>= 28, >= 26')
    assert_equal [ [ '>', 28 ] ], simplify_bounds('> 28, >= 26')

    assert_equal [ [ '<', 25 ] ], simplify_bounds('< 25, < 25')
    assert_equal [ [ '<', 24 ] ], simplify_bounds('< 25, < 24')
    assert_equal [ [ '<', 25 ] ], simplify_bounds('< 25, < 26')
    assert_equal [ [ '<', 25 ] ], simplify_bounds('< 25, <= 25')
    assert_equal [ [ '<', 25 ] ], simplify_bounds('<= 25, < 25')

    assert_equal [ [ '<', 25 ] ], simplify_bounds('< 25, <= 26')
    assert_equal [ [ '<=', 26 ] ], simplify_bounds('<= 28, <= 26')
    assert_equal [ [ '>', 28 ] ], simplify_bounds('> 28, >= 26')

    assert_equal [ [ '>', 20 ], [ '<', 25 ] ], simplify_bounds('< 25, <= 26, > 20')
    assert_equal [ [ '>', 21 ], [ '<', 25 ] ], simplify_bounds('< 25, <= 26, > 21, > 20')
    assert_equal [ [ '>', 23 ], [ '<=', 26 ] ], simplify_bounds('<= 28, <= 26, > 23, > 20')

    assert_equal [ [ '>=', 20 ], [ '<', 25 ] ], simplify_bounds('< 25, <= 26, >= 20')
    assert_equal [ [ '>=', 21 ], [ '<', 25 ] ], simplify_bounds('< 25, <= 26, >= 21, >= 20')
    assert_equal [ [ '>', 23 ], [ '<=', 26 ] ], simplify_bounds('<= 28, <= 26, > 23, >= 20')
  end
end
