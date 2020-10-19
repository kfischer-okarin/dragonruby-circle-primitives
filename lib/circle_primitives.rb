# CircleBorder Primitive
class CircleBorder
  attr_accessor :x, :y, :r, :g, :b, :a
  attr_reader :diameter

  def diameter=(value)
    @diameter = value
    @render_target_name = calc_render_target_name
    prepare_render_target unless render_target_ready?
  end

  def initialize(values)
    @x = values[:x]
    @y = values[:y]
    @r = values[:r] || 255
    @g = values[:g] || 255
    @b = values[:b] || 255
    @a = values[:a] || 255
    self.diameter = values[:diameter]
  end

  def primitive_marker
    :sprite
  end

  def draw_override(ffi_draw)
    return unless render_target_ready?

    # x, y, w, h, path
    ffi_draw.draw_sprite_3 @x, @y, @diameter, @diameter, @render_target_name,
                           # angle, alpha, red_saturation, green_saturation, blue_saturation
                           nil, @a, @r, @g, @b,
                           # tile_x, tile_y, tile_w, tile_h
                           nil, nil, nil, nil,
                           # flip_horizontally, flip_vertically,
                           nil, nil,
                           # angle_anchor_x, angle_anchor_y,
                           nil, nil,
                           # source_x, source_y, source_w, source_h
                           nil, nil, nil, nil
  end

  protected

  def calc_render_target_name
    CirclePrimitives::CircleBuilder.render_target_name(@diameter)
  end

  def prepare_render_target
    CirclePrimitives.prepare_circle_border(@diameter)
  end

  private

  def render_target_ready?
    CirclePrimitives.ready_render_targets.include? @render_target_name
  end
end

# Namespace module
module CirclePrimitives
  class << self
    def prepare_circle_border(diameter)
      CircleBuilder.new(diameter).prepare_target
    end

    def ready_render_targets
      @ready_render_targets ||= Set.new
    end

    def drawing_render_targets
      @drawing_render_targets ||= Set.new
    end
  end

  # Builds a circle by building 1/8 and then mirroring it to build a full circle
  class CircleBuilder
    def self.render_target_name(diameter)
      "circle_border_#{diameter}"
    end

    def initialize(diameter)
      @diameter = diameter
      @radius = (diameter / 2).ceil
      build
    end

    def prepare_target
      target_name = self.class.render_target_name(@diameter)
      target = $args.render_target(target_name)
      target.width = @diameter
      target.height = @diameter
      target.primitives << primitives
      CirclePrimitives.drawing_render_targets << target_name
    end

    protected

    def build
      @lines = build_quarter
      mirror_vertically
      mirror_horizontally
      translate(@radius, @radius)
    end

    def build_quarter
      eighth = CircleEighthBuilder.new(@radius).lines
      eighth + mirror_around_diagonal(eighth)
    end

    def primitives
      @lines.map { |line|
        # Fix for DragonRuby Line Render Bug
        [line.x1, line.y1 + 1, line.x2, line.y2 + 1, 255, 255, 255].line.tap { |primitive|
          lengthen_by_one(primitive, line)
        }
      }
    end

    private

    def mirror_around_diagonal(lines)
      lines.map { |line| [line.y1, line.x1, line.y2, line.x2] }
    end

    def mirror_vertically
      mirrored = @lines.map { |line| [line.x1, -line.y1 - 1, line.x2, -line.y2 - 1] }
      translate(0, -1) if @diameter.odd?
      @lines += mirrored
    end

    def mirror_horizontally
      mirrored = @lines.map { |line| [-line.x1 - 1, line.y1, -line.x2 - 1, line.y2] }
      translate(-1, 0) if @diameter.odd?
      @lines += mirrored
    end

    def translate(offset_x, offset_y)
      @lines.each do |line|
        line.x1 += offset_x
        line.x2 += offset_x
        line.y1 += offset_y
        line.y2 += offset_y
      end
    end

    def lengthen_by_one(primitive, original_line)
      # Fix for faulty DragonRuby line rendering
      primitive.x2 += (original_line.x2 >= original_line.x1 ? 1 : -1) if original_line.y1 == original_line.y2
      primitive.y2 += (original_line.y2 >= original_line.y1 ? 1 : -1) if original_line.x1 == original_line.x2
    end
  end

  # Generates lines to render a a pixel perfect 1/8th of a circle
  class CircleEighthBuilder
    attr_reader :lines

    def initialize(radius)
      @radius = radius
      @radius_sqr = @radius**2
      @lines = []
      build
    end

    private

    def build
      while @lines.empty? || last_line_in_0_to_45_degree_segment?
        next_line = build_next_line
        if longer_than_last_line?(next_line)
          revert_to_first_line_shorter_than(next_line)
          lengthen_last_line
          next
        end
        @lines << next_line
      end
    end

    def build_next_line
      last_line = @lines.last
      x = last_line ? last_line.x - 1 : @radius - 1
      y1 = last_line ? last_line.y2 + 1 : 0
      y2 = y1

      y2 += 1 while diff_to_perfect_circle(x, y2 + 1) < diff_to_perfect_circle(x - 1, y2 + 1)

      [x, y1, x, y2]
    end

    def diff_to_perfect_circle(x, y)
      ((x + 1)**2 + (y + 1)**2 - @radius_sqr).abs
    end

    def last_line_in_0_to_45_degree_segment?
      last_line = @lines.last
      last_line.y2 <= last_line.x
    end

    def length(line)
      line.y2 - line.y1 + 1
    end

    def longer_than_last_line?(line)
      last_line = @lines.last
      return false unless last_line

      length(line) > length(last_line)
    end

    def revert_to_first_line_shorter_than(too_long_line)
      line_length = length(too_long_line)
      index_of_first_shorter_line = @lines.find_index { |line| length(line) < line_length }
      @lines = @lines[0..index_of_first_shorter_line]
    end

    def lengthen_last_line
      @lines.last.y2 += 1
    end
  end

  # Minimal set implemented via hash
  class Set
    def initialize
      @values = {}
    end

    def <<(value)
      @values[value] = true
      self
    end

    def include?(value)
      @values.key? value
    end

    def empty?
      @values.empty?
    end

    def clear
      @values.clear
      self
    end

    def merge(enum)
      enum.each do |element|
        self << element
      end
      self
    end

    def each(&block)
      @values.keys.each(&block)
    end
  end

  # Updates circle render target state
  module TickCoreExtension
    def tick_core
      unless CirclePrimitives.drawing_render_targets.empty?
        CirclePrimitives.ready_render_targets.merge CirclePrimitives.drawing_render_targets
        CirclePrimitives.drawing_render_targets.clear
      end

      super
    end
  end
  GTK::Runtime.prepend TickCoreExtension
end
