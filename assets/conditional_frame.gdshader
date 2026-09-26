shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool halo = false;
void fragment() {
 float level = 0.5 + 0.5 * sin(TIME * 2.617993878);
 vec3 low = halo ? vec3(0.32, 0.07, 0.09) : vec3(0.78, 0.29, 0.32);
 vec3 high = halo ? vec3(0.40, 0.09, 0.12) : vec3(0.95, 0.42, 0.44);
 ALBEDO = mix(low, high, level);
}
