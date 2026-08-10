// Suit surface shader for Audacious workshop display.
// Handles PBR (D/N/ORM), status-tinted emissive, selection highlight pulse, and rim lighting.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex   : source_color,  filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex   : hint_normal,   filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex      :                filter_linear_mipmap, repeat_enable;
uniform sampler2D emissive_tex : source_color,  filter_linear_mipmap, repeat_enable;
uniform sampler2D specular_tex :                filter_linear_mipmap, repeat_enable;

// Status emissive — set per-surface from GDScript to reflect component condition
uniform vec4  emissive_tint    : source_color = vec4(0.15, 1.0, 0.3, 1.0);  // green = good
uniform float emissive_strength: hint_range(0.0, 8.0) = 1.5;

// Selection highlight — pulsing amber when a slot is clicked in the UI
uniform bool  highlight_active = false;
uniform vec4  highlight_color  : source_color = vec4(1.0, 0.6, 0.0, 1.0);
uniform float highlight_speed  : hint_range(0.5, 6.0) = 2.5;
uniform float highlight_intensity : hint_range(0.0, 2.0) = 0.6;

// Rim light — gives the suit a clean display-case look
uniform float rim_strength : hint_range(0.0, 3.0) = 0.8;
uniform vec4  rim_color    : source_color = vec4(0.7, 0.85, 1.0, 1.0);

// Empty slot dim — surfaces with no component are dimmed
uniform bool  is_empty_slot = false;
uniform float empty_dim     : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 albedo     = texture(albedo_tex,   UV);
	vec3 normal_map = texture(normal_tex,   UV).rgb;
	vec3 orm        = texture(orm_tex,      UV).rgb;
	vec3 emissive   = texture(emissive_tex, UV).rgb;
	float spec_mask = texture(specular_tex, UV).r;

	float dim = is_empty_slot ? empty_dim : 1.0;

	ALBEDO     = albedo.rgb * dim;
	NORMAL_MAP = normal_map;
	AO         = orm.r;
	ROUGHNESS  = orm.g;
	METALLIC   = orm.b * spec_mask;

	// Status-tinted emissive
	vec3 final_emissive = emissive * emissive_tint.rgb * emissive_strength * dim;

	// Selection highlight pulse
	if (highlight_active) {
		float pulse = sin(TIME * highlight_speed) * 0.5 + 0.5;
		final_emissive += highlight_color.rgb * pulse * highlight_intensity;
	}

	// Rim light (view-space fresnel)
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = pow(rim, 3.5);
	final_emissive += rim_color.rgb * rim * rim_strength * dim;

	EMISSION = final_emissive;
}
