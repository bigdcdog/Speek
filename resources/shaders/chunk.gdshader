
shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 chunk_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float transparency : hint_range(0.0, 1.0) = 0.2;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.08;
uniform float specular_strength : hint_range(0.0, 1.0) = 1.0;

uniform float rainbow_strength : hint_range(0.0, 2.0) = 0.8;
uniform float rainbow_scale : hint_range(1.0, 20.0) = 7.0;
uniform float rainbow_speed = 0.5;

uniform float fresnel_strength : hint_range(0.0, 2.0) = 1.0;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;

uniform float time_scale = 0.15;

void fragment() {
    vec3 normal = normalize(NORMAL);
    vec3 view_dir = normalize(VIEW);

    float facing = clamp(dot(normal, view_dir), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, fresnel_power);

    // Rainbow variation based on viewing angle.
    float rainbow_position =
        (1.0 - facing) * rainbow_scale
        + TIME * rainbow_speed;

    vec3 rainbow = 0.5 + 0.5 * cos(
        6.28318 * (
            rainbow_position / 6.0
            + vec3(0.0, 0.3333, 0.6667)
        )
    );

    // Concentrate the rainbow around the edges.
    float rainbow_mask = pow(fresnel, 1.5);

    vec3 final_color = mix(
        chunk_color.rgb,
        rainbow,
        rainbow_mask * rainbow_strength
    );

    ALBEDO = final_color;
    ALPHA = 1.0 - transparency;

    ROUGHNESS = roughness_value;
    METALLIC = 0.0;
    SPECULAR = specular_strength;

    EMISSION = rainbow * rainbow_mask * fresnel_strength * 0.35;
}
