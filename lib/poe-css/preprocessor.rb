# frozen_string_literal: true

module POECSS
  module Preprocessor
    IDENTIFIER_CHAR_REGEX = '[0-9a-zA-Z\-_]'

    class DefinitionParser < Parslet::Parser
      rule(:newline) { str("\n").repeat(1) }
      rule(:space) { match('\s').repeat(1) }
      rule(:space?) { space.maybe }
      rule(:comma) { str(',') >> space? }
      rule(:open_brace) { str('{') >> space? }
      rule(:close_brace) { str('}') >> space? }
      rule(:open_paren) { str('(') >> space? }
      rule(:close_paren) { str(')') >> space? }

      rule(:identifier) { str('@') >> match(IDENTIFIER_CHAR_REGEX.to_s).repeat >> space? }

      rule(:macro_prototype) {
        (
          identifier.as(:macro_name) >> open_paren >>
            ((identifier.as(:argument) >> comma).repeat >> identifier.as(:argument)).repeat(0, 1).as(:argument_list) >>
          close_paren
        ).as(:macro_prototype)
      }
      rule(:block_in_macro) { open_brace >> (block_in_macro | match('[^{}]')).repeat(0) >> close_brace }
      rule(:macro_definition) { (macro_prototype >> block_in_macro.as(:macro_replacement)).as(:macro) }

      rule(:constant_definition) {
        (identifier.as(:identifier) >> str(':') >> space? >> match('[^\n]').repeat(1).as(:replacement)).as(:constant_definition)
      }

      rule(:non_newline_char) { match('[^\n]') }
      rule(:nonmacro_line) { (non_newline_char.repeat(0) >> newline | non_newline_char.repeat(1)) }
      rule(:program) {
        (match('\s').repeat(0) >> (constant_definition | macro_definition | nonmacro_line.as(:nonmacro_line))).repeat(0)
      }

      root(:program)
    end

    ConstantDefinition = Struct.new(:identifier, :replacement)
    ArgumentList = Struct.new(:arguments)
    MacroDefinition = Struct.new(:identifier, :argument_list, :replacement)

    class DefinitionTransformer < Parslet::Transform
      rule(nonmacro_line: simple(:l)) { l.to_s }

      rule(constant_definition: { identifier: simple(:i), replacement: simple(:r) }) { ConstantDefinition.new(i.to_s, r.to_s) }
      rule(argument: simple(:a)) { a.to_s }
      rule(macro: {
        macro_prototype: {
          macro_name: simple(:name),
          argument_list: sequence(:args)
        },
        macro_replacement: simple(:r)
      }) { MacroDefinition.new(name.to_s, ArgumentList.new(args), r.to_s.strip[1..-2]) }
    end

    class << self
      def compile(input)
        stripped_input = input.strip
        return '' if stripped_input.empty?

        r = parse_definition(stripped_input)
        tree = DefinitionTransformer.new.apply(r)

        constants = tree.select { |n| n.is_a?(ConstantDefinition) }
        macros = tree.select { |n| n.is_a?(MacroDefinition) }
        strings = tree.select { |n| n.is_a?(String) }

        constants_by_id =
          begin
            grouping = constants.group_by(&:identifier)
            if (id, = grouping.find { |_, defs| defs.length > 1 })
              raise ArgumentError, "Multiple definitions of #{id} found."
            end

            grouping.transform_values(&:first).to_h
          end

        macros_by_id =
          begin
            grouping = macros.group_by(&:identifier)
            if (id, = grouping.find { |_, defs| defs.length > 1 })
              raise ArgumentError, "Multiple definitions of #{id} found."
            end

            grouping.transform_values(&:first).to_h
          end

        interpolate_macros(constants_by_id, macros_by_id, strings.join(''))
      end

      private

      def parse_definition(input)
        DefinitionParser.new.parse(input, reporter: Parslet::ErrorReporter::Deepest.new)
      rescue Parslet::ParseFailed => error
        raise ParseError.new(:preprocessor, error.parse_failure_cause)
      end

      class UsageParser < Parslet::Parser
        rule(:comma) { str(',') }
        rule(:open_paren) { str('(') }
        rule(:close_paren) { str(')') }

        rule(:identifier) { str('@') >> match(IDENTIFIER_CHAR_REGEX.to_s).repeat(1) }

        rule(:argument) { match('[^,)]').repeat(1).as(:argument) }
        rule(:macro_use) {
          identifier.as(:macro_name) >> open_paren >>
            ((argument >> comma).repeat >> argument).repeat(0, 1).as(:argument_list) >>
            close_paren
        }

        rule(:program) {
          (macro_use.as(:macro_use) | identifier.as(:constant_use) | match('.').as(:text)).repeat(0)
        }

        root(:program)
      end

      def interpolate_macros(constants_by_id, macros_by_id, input)
        this = self

        transform = Parslet::Transform.new do
          rule(text: simple(:s)) { s.to_s }
          rule(constant_use: simple(:s)) {
            identifier = s.to_s.strip
            constant = constants_by_id[identifier]
            raise ArgumentError, "Unknown constant #{identifier}." unless constant
            constant.replacement
          }

          rule(argument: simple(:a)) { a.to_s.strip }
          rule(
            macro_use: {
              macro_name: simple(:name),
              argument_list: sequence(:args)
            }
          ) {
            identifier = name.to_s.strip
            macro = macros_by_id[identifier]
            raise ArgumentError, "Unknown macro #{identifier}." unless macro
            if macro.argument_list.arguments.length != args.length
              raise ArgumentError, "Got #{args.length} arguments to a #{macro.argument_list.arguments.length}-argument macro."
            end

            argument_bindings = macro.argument_list.arguments.zip(args)
              .map { |argument_name, value| [ argument_name, ConstantDefinition.new(argument_name, value) ] }
              .to_h
            this.send(
              :interpolate_macros,
              constants_by_id.merge(argument_bindings),
              macros_by_id,
              macro.replacement
            )
          }
        end

        string = input

        loop do
          tree =
            begin
              UsageParser.new.parse(string, reporter: Parslet::ErrorReporter::Deepest.new)
            rescue Parslet::ParseFailed => error
              warn error.parse_failure_cause.ascii_tree
              raise
            end

          new_string = transform.apply(tree).join('')

          if new_string == string
            break
          end

          string = new_string
        end

        string
      end
    end
  end
end
