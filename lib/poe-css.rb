# frozen_string_literal: true

module POECSS
  Clause = Struct.new(:match_alternations, :inner_clauses)
  MatchClause = Struct.new(:match_key, :match_arguments)
  CommandClause = Struct.new(:command_key, :command_argument)
  RGBColorSpec = Struct.new(:r, :g, :b, :a)
  SimpleClause = Struct.new(:match_clauses, :command_clauses)

  class ParseError < StandardError
    def initialize(source, parse_trace)
      program_input = parse_trace.pos.instance_variable_get(:@string)
      deepest_error = deepest_error(parse_trace)

      line_no, col_no = deepest_error.source.line_and_column(deepest_error.pos)

      program_lines = program_input.split("\n")

      line = program_lines[line_no - 1]

      super([
        "Parse error in #{source} step:",
        '',
        program_lines[line_no - 2],
        line,
        (' ' * (col_no - 1)) + '^'
      ].compact.join("\n"))
    end

    def deepest_error(node)
      queue = [ [ node, 0 ] ]
      deepest_error = nil

      while !queue.empty?
        node, depth = queue.shift

        if node.children.empty?
          if deepest_error.nil? || deepest_error.last < depth
            deepest_error = [ node, depth ]
          end
        else
          node.children.each do |c|
            queue << [ c, depth + 1 ]
          end
        end
      end

      deepest_error.first
    end
  end

  class SimpleClause
    def inspect
      matches = 'Match (' + match_clauses.map { |s| [ s.match_key, s.match_arguments.inspect ].compact.join(' ') }.join(' ') + ')'
      commands = '{ ' + command_clauses.map { |c| [ c.command_key, c.command_argument ].compact.join(' ') }.join(', ') + ' }'
      '<' + [ matches, commands ].join(' ') + '>'
    end
  end

  class RGBColorSpec
    def inspect
      "RGBA(#{[ r, g, b, a ].map(&:inspect).join(', ')})"
    end
  end

  class << self
    def compile(input)
      # Strip comments, which is anything after a # in any line. No
      # preprocessor or POE CSS syntax uses the #, and it doesn't appear in any
      # strings (it could, but no item has a # in it), so it's safe to
      # disregard all syntax when removing comments.
      input_without_comments = input.split("\n").map { |l| l.gsub(/#.*$/, '') }.join("\n")

      # Use the preprocessor to expand constants and macros.
      preprocessed_program = Preprocessor.compile(input_without_comments)

      # Hand the contents over to the main parser, which returns a list of Clauses.
      parsed_clauses = Parser.parse_input(preprocessed_program)

      # These Clauses, each of which can contain alternations (ORs) or nested
      # clauses, get transformed into SimpleClauses. A SimpleClause is just a
      # list of ANDed match clauses and a list of commands. The nesting and
      # alternations have been expanded. We also simplify clauses here to
      # minimize inputs into the next step as well as to collapse/minimize
      # duplicated match and command keys for speed/simplicity.
      expanded_clauses = expand_clauses(parsed_clauses).map { |r| Simplifier.simplify_clause(r) }.compact

      # SimpleClauses are then converted into a list of rules in else-if form,
      # the logical flow style used by PoE. The datatype is still SimpleClause,
      # but the clauses have all been transformed and expanded to meet the
      # else-if form (I call them rules to distinguish them conceptually from
      # clauses).
      else_ifed_rules = clauses_to_else_if_rules(expanded_clauses)

      # Finally, rules that will never be hit or contribute nothing to to final
      # result are deleted. This does not remove every useless clause but is
      # likely good enough to suffice.
      rules_without_dead_rules = rules_without_dead_rules(else_ifed_rules)

      # Finally, we hand the results to the generator, which outputs them in
      # PoE item filter format.
      Generator.generate_poe_rules(rules_without_dead_rules)
    end

    private

    def expand_clauses(clauses)
      result_clauses = []

      clauses.each do |c|
        explore_clause(result_clauses, c, SimpleClause.new([], []))
      end

      result_clauses
    end

    def explore_clause(result_clauses, clause, clause_context)
      commands, nested_clauses = clause.inner_clauses.partition { |c| c.is_a?(CommandClause) }

      clause.match_alternations.each do |match_clauses|
        simple_clause = SimpleClause.new((clause_context.match_clauses + match_clauses).to_set, clause_context.command_clauses + commands)
        result_clauses << simple_clause

        nested_clauses.each do |n|
          explore_clause(result_clauses, n, simple_clause)
        end
      end
    end

    def rules_without_dead_rules(input_rules)
      rules = input_rules

      output_rules = []

      loop do
        output_rules = []

        rules.each do |r|
          if output_rules.last&.command_clauses == r.command_clauses && implies(output_rules.last, r)
            output_rules[-1] = r
          else
            output_rules << r
          end
        end

        break if rules.length == output_rules.length

        rules = output_rules
      end

      output_rules
    end

    # Return whether or not clause A being true implies that clause B must be true as well.
    def implies(clause_a, clause_b)
      simplified_clause_a = Simplifier.simplify_clause(clause_a)
      simplified_clause_b = Simplifier.simplify_clause(clause_b)

      return false if simplified_clause_a.nil? || simplified_clause_b.nil?

      clause_a_matches = simplified_clause_a.match_clauses.group_by(&:match_key)
      clause_b_matches = simplified_clause_b.match_clauses.group_by(&:match_key)

      # If B has any match keys that aren't part of A, there's no way A can imply B.
      return false unless clause_b_matches.keys.to_set.subset?(clause_a_matches.keys.to_set)

      shared_keys = clause_a_matches.keys & clause_b_matches.keys

      shared_keys.all? { |k|
        a_matches = clause_a_matches[k]
        b_matches = clause_b_matches[k]

        # If the simplifier simplifies A && B to just A, it means that B was
        # superfluous to the comparison. Specifically, A && B = A, which means
        # that when A is true, B must be true. Therefore, A implies B.
        joined_clause = Simplifier.simplify_clause(SimpleClause.new(a_matches + b_matches, []))
        joined_clause && joined_clause.match_clauses == a_matches
      }
    end

    def clauses_to_else_if_rules(clauses)
      output_rules = [ SimpleClause.new([], []) ]

      # When encountering a pair of duplicates, this eliminates the earlier one in the array, since later ones have more weight.
      unique_clauses = clauses.reverse.uniq.reverse

      # This is a modified power set algorithm adapted from the one viewable
      # here (https://github.com/sagivo/powerset/blob/master/powerset.rb).
      # This algorithm has the important property that the order of elements in
      # each sublist is the same as the order of elements in the original list,
      # which is crucial for maintaining the priority ordering of clauses.
      # Secondly, each sublist is actually the clause concatenation (ANDed) of
      # all the clauses that would be in the sublist, and impossible clauses
      # are ignored.  Finally, clauses that are generated are unique, but if
      # there is a duplicate, the earlier one is deleted because the later one
      # has higher precedence. We don't want to suppress the later one because
      # it would keep the weaker precedence, and we don't want to keep it
      # because we want to minimize the size of the output list. Powerset is a
      # 2^N operation, so we want to use deduplication and simplification
      # whenever possible to reduce the search space.
      #
      # Why do this at all? Well, the way to convert a list of clauses, any
      # subset of which may match a given item, to a list of specific else-if
      # rules is to consider the power set of the clauses, which form every
      # possible case that an item may fall into. You can then turn each
      # sublist into a single ANDed clause and sort the result by specificity
      # from most to least specific (so that the more specific rules are closer
      # to the top, whereas the reverse would suppress the rule). This is an
      # easy algorithm, but has the disadvantage of generating all 2^N
      # combinations before applying the observations above to minimize the
      # size of the result set. For a set of 24 clauses, that's already 16
      # million combinations. That's why we mix the filtering in during the
      # actual powerset algorithm.

      unique_clauses.each do |clause|
        current_length = output_rules.length

        (0...current_length).each do |i|
          rule = output_rules[i]

          concatenated_clause = Simplifier.simplify_clause(
            SimpleClause.new(
              rule.match_clauses + clause.match_clauses,
              rule.command_clauses + clause.command_clauses
            )
          )

          if concatenated_clause
            output_rules.delete(concatenated_clause)
            output_rules << concatenated_clause
          end
        end
      end

      # Our list is now sorted in specificity order from least to most
      # specific. We reverse the list and then filter out rules which would be
      # subsumed by rules earlier in the output list. These rules are useless
      # since they would be caught by the existing rule.

      rules = output_rules.drop(1) # Removes the original empty sublist.

      final_output = []

      rules.reverse.each do |r|
        if final_output.none? { |existing_rule| implies(r, existing_rule) }
          final_output << r
        end
      end

      final_output
    end
  end
end
