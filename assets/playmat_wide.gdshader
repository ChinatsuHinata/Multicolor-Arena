shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D playmat : source_color, filter_linear;
uniform float source_width;
uniform float insert_width;
uniform float left_cut;
uniform float right_cut;
uniform float source_height;
uniform float insert_height;
uniform float top_cut;
uniform float bottom_cut;
// Sakura UI lifts the black mat toward dusk plum; the defaults leave it unchanged.
uniform vec3 lift : source_color = vec3(0.0);
uniform vec3 tint : source_color = vec3(1.0);
uniform float vignette = 0.0;
uniform vec3 edge_color : source_color = vec3(0.0);

// The original art occupies 16 of the 23 horizontal world units. At these
// two quiet columns only the straight divider lines cross the image. Repeating
// those columns lengthens the field and palette without scaling text or slots.
// The vertical extension repeats quiet rows beside the central emblem. Along
// the side slots it instead repeats the empty middle row, keeping every printed
// card slot at its original height.
void fragment() {
 float x = UV.x;
 float source_x;
 if (x < left_cut * source_width) {
  source_x = x / source_width;
 } else if (x < left_cut * source_width + insert_width) {
  source_x = left_cut;
 } else if (x < right_cut * source_width + insert_width) {
  source_x = (x - insert_width) / source_width;
 } else if (x < right_cut * source_width + 2.0 * insert_width) {
  source_x = right_cut;
 } else {
  source_x = (x - 2.0 * insert_width) / source_width;
 }
 float y = UV.y;
 float source_y;
 if (source_x > 0.17 && source_x < 0.83) {
  if (y < top_cut * source_height) {
   source_y = y / source_height;
  } else if (y < top_cut * source_height + insert_height) {
   source_y = top_cut;
  } else if (y < bottom_cut * source_height + insert_height) {
   source_y = (y - insert_height) / source_height;
  } else if (y < bottom_cut * source_height + 2.0 * insert_height) {
   source_y = bottom_cut;
  } else {
   source_y = (y - 2.0 * insert_height) / source_height;
  }
 } else if (y < 0.5 * source_height) {
  source_y = y / source_height;
 } else if (y < 0.5 * source_height + 2.0 * insert_height) {
  source_y = 0.5;
 } else {
  source_y = (y - 2.0 * insert_height) / source_height;
 }
 // The printed phase reminder stacks sit between the side card slots.
 // Replace only those strips with neighboring plain background pixels.
 if (source_y > 0.416 && source_y < 0.583) {
  if (source_x > 0.068 && source_x < 0.139) {
   source_x = 0.16;
  } else if (source_x > 0.856 && source_x < 0.928) {
   source_x = 0.84;
  }
 }
 vec3 col = texture(playmat, vec2(source_x, source_y)).rgb * tint;
 ALBEDO = col + lift * (vec3(1.0) - col);
 if (vignette > 0.0) {
  // Radial falloff darkens the mat toward its rim so the centre stays readable.
  vec2 d = UV - vec2(0.5);
  float r = length(vec2(d.x * 0.92, d.y * 1.10)) * 2.0;
  float v = smoothstep(0.42, 1.35, r) * vignette;
  ALBEDO = mix(ALBEDO, edge_color, v);
  // Faint paper grain keeps large empty areas from reading as flat colour.
  float grain = fract(sin(dot(UV * vec2(1031.0, 1877.0), vec2(12.9898, 78.233))) * 43758.5453);
  ALBEDO *= 0.975 + 0.05 * grain;
 }
}
