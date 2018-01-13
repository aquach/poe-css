# frozen_string_literal: true

module POECSS
  module Parser
    module_function

    def parse_input(s)
      input = s.strip
      tree = Parser.new.parse(input, reporter: Parslet::ErrorReporter::Deepest.new)
      Transformer.new.apply(tree)
    rescue Parslet::ParseFailed => error
      raise ParseError.new(:parser, error.parse_failure_cause)
    end

    class Parser < Parslet::Parser
      def stri(str)
        str.split('').map { |char| match["#{char.upcase}#{char.downcase}"] }.reduce(:>>)
      end

      rule(:newline) { match("\n").repeat(1) }
      rule(:space) { match('\s').repeat(1) }
      rule(:space?) { space.maybe }
      rule(:comma) { str(',') >> space? }
      rule(:pipe) { str('|') >> space? }
      rule(:open_brace) { str('{') >> space? }
      rule(:close_brace) { str('}') >> space? }

      rule(:operator) { (str('>=') | str('<=') | str('>') | str('<') | str('=')).as(:operator) >> space? }

      rule(:integer) { match('[0-9]').repeat(1).as(:integer) >> space? }
      rule(:rarity) { (stri('Normal') | stri('Magic') | stri('Rare') | stri('Unique')).as(:rarity) >> space? }
      rule(:string) {
        ((str('"') >> match(%([a-zA-Z0-9' ])).repeat(1).as(:string) >> str('"')) | match(%([a-zA-Z0-9'])).repeat(1).as(:string)) >> space?
      }
      rule(:strings) { string.repeat(1).as(:strings) }
      rule(:rgb_color_spec) {
        stri('RGB') >> stri('A').maybe >> str('(') >> space? >>
          integer.as(:r) >> comma >>
          integer.as(:g) >> comma >>
          integer.as(:b) >>
          (comma >> integer.as(:a)).maybe >>
          str(')') >> space?
      }
      rule(:color_spec) {
        rgb_color_spec.as(:rgb)
      }
      rule(:sound_spec) {
        integer.as(:sound_id) >> integer.as(:volume).maybe
      }
      rule(:boolean) { (stri('true') | stri('false')).as(:boolean) >> space? }

      rule(:match_item_level) {
        stri('ItemLevel').as(:match_key) >> space? >> (operator.maybe.as(:operator) >> integer.as(:level)).as(:match_arguments)
      }
      rule(:match_drop_level) {
        stri('DropLevel').as(:match_key) >> space? >> (operator.maybe.as(:operator) >> integer.as(:level)).as(:match_arguments)
      }
      rule(:match_quality) {
        stri('Quality').as(:match_key) >> space? >> (operator.maybe.as(:operator) >> integer.as(:quality)).as(:match_arguments)
      }
      rule(:match_rarity) {
        stri('Rarity').as(:match_key) >> space? >> (operator.maybe.as(:operator) >> rarity.as(:rarity)).as(:match_arguments)
      }
      rule(:match_class) {
        stri('Class').as(:match_key) >> space? >> strings.as(:substrings).as(:match_arguments)
      }
      rule(:match_base_type) {
        stri('BaseType').as(:match_key) >> space? >> strings.as(:substrings).as(:match_arguments)
      }
      rule(:match_sockets) {
        stri('Sockets').as(:match_key) >> space? >> (operator.maybe.as(:operator) >> integer.as(:sockets)).as(:match_arguments)
      }
      rule(:match_linked_sockets) {
        stri('LinkedSockets').as(:match_key) >> space? >> (operator.maybe.as(:operator) >> integer.as(:sockets)).as(:match_arguments)
      }
      rule(:match_socket_group) {
        stri('SocketGroup').as(:match_key) >> space? >> strings.as(:sub_socket_groups).as(:match_arguments)
      }
      rule(:match_height) {
        stri('Height').as(:match_key) >> space? >> (operator.maybe.as(:operator) >> integer.as(:height)).as(:match_arguments)
      }
      rule(:match_width) {
        stri('Width').as(:match_key) >> space? >> (operator.maybe.as(:operator) >> integer.as(:width)).as(:match_arguments)
      }
      rule(:match_identified) {
        stri('Identified').as(:match_key) >> space? >> boolean.maybe.as(:identified).as(:match_arguments)
      }
      rule(:match_corrupted) {
        stri('Corrupted').as(:match_key) >> space? >> boolean.maybe.as(:corrupted).as(:match_arguments)
      }
      rule(:match_elder_item) {
        stri('ElderItem').as(:match_key) >> space? >> boolean.maybe.as(:elder_item).as(:match_arguments)
      }
      rule(:match_shaped_map) {
        stri('ShapedMap').as(:match_key) >> space? >> boolean.maybe.as(:shaped_map).as(:match_arguments)
      }
      rule(:match_shaper_item) {
        stri('ShaperItem').as(:match_key) >> space? >> boolean.maybe.as(:shaper_item).as(:match_arguments)
      }

      rule(:match_clause) {
        (
          match_item_level |
          match_drop_level |
          match_quality |
          match_rarity |
          match_class |
          match_base_type |
          match_sockets |
          match_linked_sockets |
          match_socket_group |
          match_height |
          match_width |
          match_identified |
          match_corrupted |
          match_elder_item |
          match_shaped_map |
          match_shaper_item
        )
      }

      rule(:command_set_border_color) { stri('SetBorderColor').as(:command_key) >> space? >> color_spec.as(:color).as(:command_argument) }
      rule(:command_set_text_color) { stri('SetTextColor').as(:command_key) >> space? >> color_spec.as(:color).as(:command_argument) }
      rule(:command_set_bg_color) { stri('SetBackgroundColor').as(:command_key) >> space? >> color_spec.as(:color).as(:command_argument) }
      rule(:command_play_alert_sound) { stri('PlayAlertSound').as(:command_key) >> space? >> sound_spec.as(:command_argument) }
      rule(:command_play_alert_sound_positional) { stri('PlayAlertSoundPositional').as(:command_key) >> space? >> sound_spec.as(:command_argument) }
      rule(:command_set_font_size) { stri('SetFontSize').as(:command_key) >> space? >> integer.as(:font_size).as(:command_argument) }

      rule(:command_clause) {
        (
          (stri('Show').as(:command_key) >> space?) |
          (stri('Hide').as(:command_key) >> space?) |
          command_set_border_color |
          command_set_text_color |
          command_set_bg_color |
          command_play_alert_sound |
          command_play_alert_sound_positional |
          command_set_font_size
        )
      }

      rule(:match_alternation) {
        ((match_clause >> comma).repeat(0) >> match_clause).as(:match_clauses)
      }

      rule(:clause) {
        ((match_alternation >> pipe).repeat(0) >> match_alternation).as(:match_alternations) >> open_brace >>
          (command_clause | clause).repeat(1).as(:inner_clauses) >> close_brace
      }
      rule(:clauses) { clause.repeat(0) }
      root(:clauses)
    end

    class Transformer < Parslet::Transform
      rule(integer: simple(:i)) { Integer(i) }
      rule(operator: simple(:o)) { o.to_s }
      rule(rarity: simple(:o)) { o.to_s }
      rule(string: simple(:s)) { s.to_s }
      rule(strings: sequence(:s)) { s }
      rule(boolean: simple(:b)) { b.to_s.downcase == 'true'.downcase }
      rule(sockets: simple(:g)) { g.to_s.upcase }
      rule(rgb: { r: simple(:r), g: simple(:g), b: simple(:b), a: simple(:a) }) { RGBColorSpec.new(r, g, b, a) }
      rule(rgb: { r: simple(:r), g: simple(:g), b: simple(:b) }) { RGBColorSpec.new(r, g, b, nil) }

      rule(sub_socket_groups: sequence(:groups)) {
        { sub_socket_groups: groups.map(&:upcase) }
      }

      rule(match_key: simple(:k), match_arguments: subtree(:a)) { MatchClause.new(k.to_s.downcase, a) }
      rule(command_key: simple(:k), command_argument: subtree(:a)) { CommandClause.new(k.to_s.downcase, a) }
      rule(command_key: simple(:k)) { CommandClause.new(k.to_s.downcase, nil) }
      rule(match_alternations: subtree(:alternations), inner_clauses: subtree(:inner_clauses)) {
        Clause.new([ alternations ].flatten.map { |match_clauses| [ match_clauses[:match_clauses] ].flatten }, inner_clauses)
      }
    end
  end
end
