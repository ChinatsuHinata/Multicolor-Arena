shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
 vec2 cell = floor(UV * vec2(195.0, 272.0));
 float tick = floor(TIME * 18.0);
 float grain = fract(sin(dot(cell + vec2(tick, tick * 0.37), vec2(12.9898, 78.233))) * 43758.5453);
 ALBEDO = vec3(0.08 + grain * 0.84);
 ALPHA = 0.88;
}
