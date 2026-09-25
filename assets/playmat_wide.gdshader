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
 ALBEDO = texture(playmat, vec2(source_x, source_y)).rgb;
}
