# frozen_string_literal: true

require 'minitest'
require 'minitest/autorun'

require_relative '../../lib/dependencies'

class StricterQueryTest < Minitest::Test
  def stricter_query?(a, b)
    POECSS::Simplifier.send(:stricter_query?, a, b)
  end

  def test_is_stricter_query
    assert stricter_query?(%w[alice bob carol], %w[alice bob carol])
    assert stricter_query?(%w[alice bob carol], %w[alic bo carol])
    assert stricter_query?(%w[alice bob carol], %w[alic bo caro])
    refute stricter_query?(%w[alice bob carol], %w[alic bo carolf])

    refute stricter_query?(%w[alice bob carol], %w[alic bo])
    assert stricter_query?(%w[alice], %w[alic bo])
    assert stricter_query?(%w[alice bob b], %w[alic b])
    refute stricter_query?(%w[a b c], %w[a b])
  end
end
