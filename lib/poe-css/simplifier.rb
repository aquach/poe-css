# frozen_string_literal: true

module POECSS
  module Simplifier
    RARITY_TO_NUMBER = { 'Normal' => 0, 'Magic' => 1, 'Rare' => 2, 'Unique' => 3 }
    NUMBER_TO_RARITY = RARITY_TO_NUMBER.invert

    class << self
      # Removes impossible matches, duplicate matches, and duplicate commands.
      def simplify_clause(clause)
        simplified_matches = clause.match_clauses.group_by(&:match_key).flat_map { |match_key, matches|
          case match_key
          when 'itemlevel', 'droplevel', 'quality', 'height', 'width', 'sockets', 'linkedsockets'
            simplify_numeric_matches(match_key, matches)
          when 'rarity'
            simple_bounds = simplify_bounds(
              matches.map { |m| [ m.match_arguments[:operator] || '=', RARITY_TO_NUMBER[m.match_arguments[:rarity]] ] }
            )

            simple_bounds&.map { |op, limit| MatchClause.new(match_key, { operator: op, rarity: NUMBER_TO_RARITY[limit] }) }
          when 'basetype', 'class', 'socketgroup'
            key =
              case match_key
              when 'basetype', 'class'
                :substrings
              when 'socketgroup'
                :sub_socket_groups
              else
                raise ArgumentError, key
              end

            # Matches a QUERY if for all match in matches, match.substrings.any? { |substring| QUERY[substring] }.
            matches_with_simplified_substrings = matches.uniq.map { |match|
              # We're in an OR-ing context now, so get rid of any substring
              # which is already subsumed by a different substring. If A is a
              # substring of B, then if QUERY[B] is true, then QUERY[A] must
              # also be true, so B can be eliminated from QUERY[A] || QUERY[B].
              queries = []
              match.match_arguments[key].sort_by(&:length).each do |s|
                if queries.none? { |q| s[q] }
                  queries << s
                end
              end

              MatchClause.new(match_key, { key => queries })
            }

            # Now look for cases where a match can be subsumed by another
            # match. If match A's queries are a subset of match B's, then
            # match B is more restrictive than match A and match A can be
            # removed.

            matches = []
            matches_with_simplified_substrings.sort_by { |m| m.match_arguments[key].length }.each do |s|
              if matches.none? { |q| stricter_query?(q.match_arguments[key], s.match_arguments[key]) }
                matches << s
              end
            end

            matches
          when 'corrupted', 'elderitem', 'identified', 'shapedmap', 'shaperitem'
            key =
              case match_key
              when 'corrupted'
                :corrupted
              when 'elderitem'
                :elder_item
              when 'identified'
                :identified
              when 'shapedmap'
                :shaped_map
              when 'shaperitem'
                :shaper_item
              else
                raise ArgumentError, key
              end

            values = matches.map { |m| m.match_arguments[key] }.uniq

            if values.length == 1
              MatchClause.new(match_key, { key => values.first })
            end
          else
            raise ArgumentError, match_key
          end
        }

        # Some match reported that the match was impossible.
        return nil if simplified_matches.any?(&:nil?)

        # Only the last command of a particular key is used.
        simplified_commands = clause.command_clauses
          .group_by { |c|
            case c.command_key
            when 'show', 'hide' # Show and Hide need to be grouped together.
              'showhide'
            else
              c.command_key
            end
          }
          .map { |_, cs| cs.last }

        SimpleClause.new(simplified_matches, simplified_commands)
      end

      private

      # A and B are lists of strings intended to be used in substring tests.
      # QUERY(string, query) = query.any? { |q| string[q] }
      # Returns true if for all strings to QUERY(string, A) that return true, QUERY(string, B) also returns true.
      def stricter_query?(a_substrings, b_substrings)
        a_substrings.all? { |a_query| b_substrings.any? { |b_query| a_query[b_query] } }
      end

      def simplify_numeric_matches(match_key, matches)
        key =
          case match_key
          when 'itemlevel'
            :level
          when 'droplevel'
            :level
          when 'quality'
            :quality
          when 'rarity'
            :rarity
          when 'height'
            :height
          when 'sockets'
            :sockets
          when 'linkedsockets'
            :sockets
          when 'width'
            :width
          else
            raise ArgumentError, match_key
          end
        simple_bounds = simplify_bounds(matches.map { |m| [ m.match_arguments[:operator] || '=', m.match_arguments[key] ] })

        simple_bounds&.map { |op, limit| MatchClause.new(match_key, { operator: op, key => limit }) }
      end

      def simplify_bounds(bounds)
        lower = -Float::INFINITY
        lower_inclusive = nil
        upper = Float::INFINITY
        upper_inclusive = nil

        bounds.each do |op, limit|
          case op
          when '>='
            if limit > lower
              lower = limit
              lower_inclusive = true
            end
          when '>'
            if limit >= lower
              lower = limit
              lower_inclusive = false
            end
          when '='
            if limit > lower
              lower = limit
              lower_inclusive = true
            end
            if limit < upper
              upper = limit
              upper_inclusive = true
            end
          when '<'
            if limit <= upper
              upper = limit
              upper_inclusive = false
            end
          when '<='
            if limit < upper
              upper = limit
              upper_inclusive = true
            end
          else
            raise ArgumentError, op
          end
        end

        if lower == upper && upper_inclusive && lower_inclusive
          [
            [ '=', lower ]
          ]
        elsif lower < upper
          [
            if lower != -Float::INFINITY
              [ lower_inclusive ? '>=' : '>', lower ]
            end,
            if upper != Float::INFINITY
              [ upper_inclusive ? '<=' : '<', upper ]
            end
          ].compact
        end
      end
    end
  end
end
