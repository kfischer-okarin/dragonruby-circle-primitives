require 'lib/circle_primitives.rb'

def tick(args)
  return if args.tick_count.zero?

  args.state.circle ||= CircleBorder.new(x: 0, y: 0, diameter: 20, r: 255, g: 0, b: 0)
  setup_canvas(args)

  render(args)

  update_diameter_via_arrow_keys(args)
end

def render(args)
  canvas_target(args).primitives << args.state.circle

  args.outputs.sprites << rendered_canvas(args)
  args.outputs.labels << [0, 20, "Circle Diameter: #{args.state.circle.diameter}", 0, 0, 0]
end

CANVAS_RENDER_TARGET = :canvas

def setup_canvas(args)
  canvas_size = fitting_size(args.state.circle.diameter)
  args.state.canvas = {
    x: 0, y: 0, w: 1280, h: 720,
    path: CANVAS_RENDER_TARGET, source_x: 0, source_y: 0, source_w: canvas_size.x, source_h: canvas_size.y
  }
end

def fitting_size(diameter)
  height = [72, 90, 144, 180, 360, 720].find { |h| h >= diameter }
  [height.idiv(9) * 16, height]
end

def canvas_target(args)
  args.outputs[CANVAS_RENDER_TARGET]
end

def rendered_canvas(args)
  args.state.canvas
end

def key_down_or_held?(args, key)
  keyboard = args.inputs.keyboard
  keyboard.key_down.send(key) || (keyboard.key_held.send(key) && args.tick_count.mod_zero?(5))
end

def update_diameter_via_arrow_keys(args)
  args.state.circle.diameter += 1 if key_down_or_held?(args, :up)
  args.state.circle.diameter -= 1 if key_down_or_held?(args, :down)
end
