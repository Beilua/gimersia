shader_type canvas_item;

void fragment() {
    // Ambil alpha dari tekstur tapi pakai warna putih solid
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(vec3(1.0), tex.a);
}
