uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

// Tempo e tamanho da sprite:
uniform float u_GlobalTime; 
uniform float u_SpriteSize;
uniform float u_AlphaThreshold;

// (Opcional) Pode usar, se precisar do tamanho de tela da textura
uniform vec2 u_Resolution;

// (Você tinha "const float width = 1.0 / 128.0;", 
// mas vamos substituí-lo pela lógica condicional de width.)
void main(void)
{
    // Pegamos a cor do pixel atual
    vec4 col = texture2D(u_Tex0, v_TexCoord);

    // Define 'width' conforme o tamanho da sprite (u_SpriteSize).
    float width;
    if (abs(u_SpriteSize - 64.0) < 0.5) {
        width = 1.0 / 64.0;    // contorno para sprite ~64x64
    }
    else if (abs(u_SpriteSize - 128.0) < 0.5) {
        width = 1.0 / 128.0;    // contorno para sprite ~128x128
    }
    else if (abs(u_SpriteSize - 256.0) < 0.5) {
        width = 1.0 / 256.0;   // contorno para sprite ~256x256
    }
    else {
        // valor padrão, caso o spriteSize não seja próximo de 64/128/256
        width = 1.0 / 256.0;
    }

    // Se for um pixel "opaco" (parte da criatura), descartamos neste pass
    if (col.a > u_AlphaThreshold) {
        discard;
    } else {
        // Checamos se há algum vizinho opaco. Agora incluímos as diagonais.
        float alphaLeft      = texture2D(u_Tex0, v_TexCoord + vec2(-width, 0.0)).a;
        float alphaRight     = texture2D(u_Tex0, v_TexCoord + vec2( width, 0.0)).a;
        float alphaUp        = texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  width)).a;
        float alphaDown      = texture2D(u_Tex0, v_TexCoord + vec2( 0.0, -width)).a;

        float alphaUpLeft    = texture2D(u_Tex0, v_TexCoord + vec2(-width,  width)).a;
        float alphaUpRight   = texture2D(u_Tex0, v_TexCoord + vec2( width,  width)).a;
        float alphaDownLeft  = texture2D(u_Tex0, v_TexCoord + vec2(-width, -width)).a;
        float alphaDownRight = texture2D(u_Tex0, v_TexCoord + vec2( width, -width)).a;

        bool isBorder = (
            alphaLeft      > u_AlphaThreshold ||
            alphaRight     > u_AlphaThreshold ||
            alphaUp        > u_AlphaThreshold ||
            alphaDown      > u_AlphaThreshold ||
            alphaUpLeft    > u_AlphaThreshold ||
            alphaUpRight   > u_AlphaThreshold ||
            alphaDownLeft  > u_AlphaThreshold ||
            alphaDownRight > u_AlphaThreshold
        );

        if (isBorder) {
            // Calcular um gradiente de cor baseado no tempo e em v_TexCoord
            float speedFactor = 0.5;
            float hue = mod((v_TexCoord.y - u_GlobalTime * speedFactor) * 3.0, 1.0);

            // Cores
            vec3 blue      = vec3(0.0, 0.5, 1.0);
            vec3 gold      = vec3(1.0, 0.8, 0.0);
            vec3 whiteBlue = vec3(0.8, 0.9, 1.0);

            // Interpolação suave entre as 3 cores
            vec3 allianceColor;
            if (hue < 0.333333) {
                allianceColor = mix(blue, gold, (hue / 0.33));
            } else if (hue < 0.666666) {
                allianceColor = mix(gold, whiteBlue, (hue - 0.33) / 0.33);
            } else {
                allianceColor = mix(whiteBlue, blue, (hue - 0.66) / 0.34);
            }

            gl_FragColor = vec4(allianceColor, 0.8);
        } else {
            // Se não há vizinho opaco, descarta.
            discard;
        }
    }
}
