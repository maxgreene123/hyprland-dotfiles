#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

// Set this value higher for more vibrance (e.g., 0.75 to 1.0)
const float VIB_VIBRANCE = 1.0;
const vec3 VIB_RGB_BALANCE = vec3(1.0, 1.0, 1.0);
const vec3 VIB_coeffVibrance = VIB_RGB_BALANCE * -VIB_VIBRANCE;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    vec3 color = vec3(pixColor[0], pixColor[1], pixColor[2]);

    // Luma coefficients for grayscale calculation
    const vec3 VIB_coefLuma = vec3(0.212656, 0.715158, 0.072186);
    float luma = dot(VIB_coefLuma, color);

    float max_color = max(color[0], max(color[1], color[2]));
    float min_color = min(color[0], min(color[1], color[2]));
    float color_saturation = max_color - min_color;

    vec3 p_col = vec3(vec3(vec3(vec3(sign(VIB_coeffVibrance) * color_saturation) - 1.0) * VIB_coeffVibrance) + 1.0);

    pixColor[0] = mix(luma, color[0], p_col[0]);
    pixColor[1] = mix(luma, color[1], p_col[1]);
    pixColor[2] = mix(luma, color[2], p_col[2]);

    fragColor = pixColor;
}
