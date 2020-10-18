require 'lib/circle_primitives.rb'

def tick(args)
  return if args.tick_count.zero?

  setup_canvas(args)

  canvas_target(args).primitives << CircleBorder.new(x: 0, y: 0, diameter: 20, r: 255, g: 0, b: 0)

  args.outputs.sprites << rendered_canvas(args)
end

CANVAS_RENDER_TARGET = :canvas

def setup_canvas(args)
  args.state.canvas ||= {
    x: 0, y: 0, w: 1280, h: 720,
    path: CANVAS_RENDER_TARGET, source_x: 0, source_y: 0, source_w: 128, source_h: 72
  }
end

def canvas_target(args)
  args.outputs[CANVAS_RENDER_TARGET]
end

def rendered_canvas(args)
  args.state.canvas
end
