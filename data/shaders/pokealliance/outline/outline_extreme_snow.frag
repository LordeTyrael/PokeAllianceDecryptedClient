uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;
uniform float u_GlobalTime;

// Tons de azul
const vec4 lightBlue = vec4(0.4, 0.6, 1.0, 0.8); // Azul claro com 80% de opacidade
const vec4 deepBlue = vec4(0.0, 0.2, 0.6, 0.8);  // Azul profundo com 80% de opacidade
const float width = 1.0 / 224.0;
float speedFactor = 5.0; // Velocidade do pulso

void main(void)
{
    vec4 col = texture2D(u_Tex0, v_TexCoord);
    if (col.a > 0.0) {
        discard;
    } else {
        float alphaLeft   = texture2D(u_Tex0, vec2(v_TexCoord.x - width, v_TexCoord.y)).a;
        float alphaRight  = texture2D(u_Tex0, vec2(v_TexCoord.x + width, v_TexCoord.y)).a;
        float alphaUp     = texture2D(u_Tex0, vec2(v_TexCoord.x, v_TexCoord.y + width)).a;
        float alphaDown   = texture2D(u_Tex0, vec2(v_TexCoord.x, v_TexCoord.y - width)).a;

        if (alphaLeft > 0.0 || alphaRight > 0.0 || alphaUp > 0.0 || alphaDown > 0.0) {
            // Calcula o pulso
            float pulse = 0.5 + 0.7 * sin(u_GlobalTime * speedFactor); // Oscila entre 0.5 e 1.0

            // Interpola entre os tons de azul
            vec4 outlineCol = mix(deepBlue, lightBlue, pulse);

            gl_FragColor = vec4(outlineCol.rgb, outlineCol.a);
        } else {
            discard; // Descarta pixels transparentes que não estão na borda
        }
    }
}
