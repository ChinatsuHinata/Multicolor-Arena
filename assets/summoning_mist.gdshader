shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Wisps sit beyond the blue/yellow selection border; the card face stays clear.
void fragment() {
 vec2 p = (UV - vec2(0.5)) * 2.0;
 float radius = length(p);
 float angle = atan(p.y, p.x);
 float orbit = angle + TIME * 0.65;
 float drift = sin(angle * 4.0 - TIME * 1.4) * 0.025;
 float ring = exp(-pow((radius - 0.83 - drift) / 0.075, 2.0));
 float wisps = 0.2 + 0.8 * pow(0.5 + 0.5 * sin(orbit * 3.0), 3.0);
 ALBEDO = vec3(0.60, 0.83, 1.0);
 ALPHA = ring * wisps * 0.7;
}
