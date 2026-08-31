uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;
uniform float u_GlobalTime;

const float width = 1.0 / 224.0; // Largura do contorno

void main(void)
{
    vec4 col = texture2D(u_Tex0, v_TexCoord);
    
    if (col.a > 0.0) {
        discard;
    } else {
        float alphaLeft   = texture2D(u_Tex0, v_TexCoord + vec2(-width, 0.0)).a;
        float alphaRight  = texture2D(u_Tex0, v_TexCoord + vec2(width, 0.0)).a;
        float alphaUp     = texture2D(u_Tex0, v_TexCoord + vec2(0.0, width)).a;
        float alphaDown   = texture2D(u_Tex0, v_TexCoord + vec2(0.0, -width)).a;

        if (alphaLeft > 0.0 || alphaRight > 0.0 || alphaUp > 0.0 || alphaDown > 0.0) {
            // Cor fixa: Azul
            vec3 fixedColor = vec3(0.0, 0.5, 1.0); // Azul fixo

            // Cor pulsante: Branco que desce
            float speedFactor = 1.0; // Velocidade do movimento descendente
            float pulse = 0.5 + 0.25 * sin((v_TexCoord.y - u_GlobalTime * speedFactor) * 6.28318);
            vec3 pulseColor = vec3(1.0) * pulse; // Branco pulsante

            // Combina a cor fixa com o contorno pulsante
            vec3 finalColor = mix(fixedColor, pulseColor, pulse);

            gl_FragColor = vec4(finalColor, 0.8);  // Aplica o contorno
        } else {
            discard;
        }
    }
}
