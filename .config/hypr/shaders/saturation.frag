#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const float saturation = 1.3;   // 1.0 = normal
const float contrast   = 1.0;
const float brightness = 0.0;

void main() {
    vec4 c = texture(tex, v_texcoord);
    float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 rgb = mix(vec3(l), c.rgb, saturation);
    rgb = (rgb - 0.5) * contrast + 0.5 + brightness;
    fragColor = vec4(rgb, c.a);
}
