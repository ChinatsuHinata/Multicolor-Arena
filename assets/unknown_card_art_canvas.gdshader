shader_type canvas_item;

void fragment() {
 vec4 original = texture(TEXTURE, UV) * COLOR;
 vec2 cell = floor(UV * vec2(195.0, 272.0));
 float tick = floor(TIME * 18.0);
 float grain = fract(sin(dot(cell + vec2(tick, tick * 0.37), vec2(12.9898, 78.233))) * 43758.5453);
 COLOR = vec4(mix(original.rgb, vec3(0.08 + grain * 0.84), 0.88), original.a);
}
