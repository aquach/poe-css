# frozen_string_literal: true

module POECSS
  module Generator
    class << self
      def generate_poe_rules(clauses)
        clauses.map { |clause|
          visibility_command_clauses, nonvisibility_command_clauses = [
            clause.command_clauses
          ].flatten.partition { |c| c.command_key == 'show' || c.command_key == 'hide' }
          visibility_command_clause = visibility_command_clauses.first
          if visibility_command_clause.nil?
            raise ArgumentError, "Each generated clause must have a Show or Hide command.\n\n#{clause}"
          end

          visibility_header = visibility_command_clause.command_key.capitalize

          match_rules = clause.match_clauses.map { |c|
            args = c.match_arguments
            arguments =
              case c.match_key
              when 'itemlevel'
                [ 'ItemLevel', args[:operator], args[:level] ]
              when 'droplevel'
                [ 'DropLevel', args[:operator], args[:level] ]
              when 'quality'
                [ 'Quality', args[:operator], args[:quality] ]
              when 'rarity'
                [ 'Rarity', args[:operator], args[:rarity] ]
              when 'class'
                [ 'Class', args[:substrings].sort.map(&:inspect) ]
              when 'basetype'
                [ 'BaseType', args[:substrings].sort.map(&:inspect) ]
              when 'corrupted'
                [ 'Corrupted', bool(args[:corrupted]) ]
              when 'elderitem'
                [ 'ElderItem', bool(args[:elder_item]) ]
              when 'height'
                [ 'Height', args[:operator], args[:height] ]
              when 'identified'
                [ 'Identified', bool(args[:identified]) ]
              when 'linkedsockets'
                [ 'LinkedSockets', args[:operator], args[:sockets] ]
              when 'shapedmap'
                [ 'ShapedMap', bool(args[:shaped_map]) ]
              when 'shaperitem'
                [ 'ShaperItem', bool(args[:shaper_item]) ]
              when 'socketgroup'
                [ 'SocketGroup', args[:sub_socket_groups].sort_by { |s| [ -s.length, s ] }.map(&:inspect) ]
              when 'sockets'
                [ 'Sockets', args[:operator], args[:sockets] ]
              when 'width'
                [ 'Width', args[:operator], args[:width] ]
              else
                raise ArgumentError, c.match_key
              end

            arguments.flatten.join(' ')
          }

          nonvisibility_commands = nonvisibility_command_clauses.map { |c|
            arg = c.command_argument
            arguments =
              case c.command_key
              when 'setbordercolor'
                [ 'SetBorderColor', color_from_spec(arg[:color]) ]
              when 'settextcolor'
                [ 'SetTextColor', color_from_spec(arg[:color]) ]
              when 'setbackgroundcolor'
                [ 'SetBackgroundColor', color_from_spec(arg[:color]) ]
              when 'playalertsound'
                [ 'PlayAlertSound', arg[:sound_id], arg[:volume] ]
              when 'playalertsoundpositional'
                [ 'PlayAlertSoundPositional', arg[:sound_id], arg[:volume] ]
              when 'setfontsize'
                [ 'SetFontSize', arg[:font_size] ]
              else
                raise ArgumentError, c.command_key
              end

            arguments.flatten.compact.join(' ')
          }

          [
            visibility_header.to_s,
            match_rules.sort.map { |r| "  #{r}" }.join("\n"),
            nonvisibility_commands.sort.map { |r| "  #{r}" }.join("\n")
          ].reject(&:empty?).join("\n") + "\n"
        }.join("\n")
      end

      private

      def color_from_spec(spec)
        case spec
        when RGBColorSpec
          (%i[r g b].map { |c| spec[c] } + [ spec.a || 255 ]).join(' ')
        else
          raise ArgumentError, spec
        end
      end

      def bool(b)
        (!b.nil? ? b : true).to_s.capitalize
      end
    end
  end
end
