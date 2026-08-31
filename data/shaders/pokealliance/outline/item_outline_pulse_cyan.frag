uniform mat4 u_Color;
varying vec2 v_TexCoord;
varying vec2 v_TexCoord2;
varying vec2 v_TexCoord3;
varying vec2 v_Position;
uniform sampler2D u_Tex0;
uniform float u_GlobalTime;
uniform vec2 u_Resolution;

void main()
{
    gl_FragColor = texture2D(u_Tex0, v_TexCoord);
    vec4 texcolor = texture2D(u_Tex0, v_TexCoord2);
    vec4 texcolor2 = texture2D(u_Tex0, v_TexCoord3);
    if (texcolor.r > 0.9) {
        if (texcolor.g > 0.9) {
            gl_FragColor *= u_Color[1]; // Vermelho
        } else {
            gl_FragColor *= mix(u_Color[1], u_Color[0], 0.5); // Vermelho misturado com amarelo
        }
    } else if (texcolor.g > 0.9) {
        gl_FragColor *= u_Color[0]; // Amarelo
    }
    if (gl_FragColor.a < 0.01) {
        if (texcolor2.a > 0.01) {
            float pulseDuration = 2.0; // Duração total do ciclo de pulsação (subida e descida)
            float time = mod(u_GlobalTime, pulseDuration);
            float position = (time < 1.0) ? time : 1.0 - (time - 1.0); // Movimentação de cima para baixo e volta

            vec3 pulsatingColor = vec3(0.0, 1.0, 1.0); // Cor ciano
            float alpha = smoothstep(0.0, 1.0, position);
            vec4 pulsatingEffect = vec4(pulsatingColor, alpha);

            gl_FragColor = pulsatingEffect;
        } else {
            discard;
        }
    }
}
