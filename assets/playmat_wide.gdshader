shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D playmat : source_color, filter_linear;
uniform float source_width;
uniform float insert_width;
uniform float left_cut;
uniform float right_cut;

// The original art occupies 16 of the 23 horizontal world units. At these
// two quiet columns only the straight divider lines cross the image. Repeating
// those columns lengthens the field and palette without scaling text or slots.
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
 // The printed phase reminder stacks sit between the side card slots.
 // Replace only those strips with neighboring plain background pixels.
 if (UV.y > 0.416 && UV.y < 0.583) {
  if (source_x > 0.068 && source_x < 0.139) {
   source_x = 0.16;
  } else if (source_x > 0.856 && source_x < 0.928) {
   source_x = 0.84;
  }
 }
 ALBEDO = texture(playmat, vec2(source_x, UV.y)).rgb;
}
