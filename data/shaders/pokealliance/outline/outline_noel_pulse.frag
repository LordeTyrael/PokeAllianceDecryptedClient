uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

// Uniforms
uniform float u_GlobalTime;
uniform float u_SpriteSize;   // Largura/altura da sprite (64, 128, 256, etc.)

// Cores de Natal
const vec4 redNoel  = vec4(1.0, 0.25, 0.25, 0.60); // Vermelho suave (60% opaco)
const vec4 blueSnow = vec4(0.3, 0.5, 0.8, 0.8);   // Azul suave (80% opaco)

// Velocidade de pulsação
const float speed = 6.0;

void main(void)
{
    // Cor do pixel atual
    vec4 col = texture2D(u_Tex0, v_TexCoord);

    // Define o 'width' de acordo com o tamanho da sprite
    float width;
    if (abs(u_SpriteSize - 64.0) < 0.5) {
        width = 1.0 / 64.0;
    } else if (abs(u_SpriteSize - 128.0) < 0.5) {
        width = 1.0 / 128.0;
    } else if (abs(u_SpriteSize - 256.0) < 0.5) {
        width = 1.0 / 256.0;
    } else {
        // valor padrão, caso não bata 64/128/256
        width = 1.0 / 240.0; 
    }

    // Se este pixel é "opaco" (parte da criatura), descartamos neste pass
    if (col.a > 0.0) {
        discard;
    } else {
        // 1) Verifica se ALGUM dos 8 vizinhos é opaco -> estamos em borda
        float alphaLeft      = texture2D(u_Tex0, v_TexCoord + vec2(-width,  0.0)).a;
        float alphaRight     = texture2D(u_Tex0, v_TexCoord + vec2( width,  0.0)).a;
        float alphaUp        = texture2D(u_Tex0, v_TexCoord + vec2( 0.0,   +width)).a;
        float alphaDown      = texture2D(u_Tex0, v_TexCoord + vec2( 0.0,   -width)).a;

        float alphaUpLeft    = texture2D(u_Tex0, v_TexCoord + vec2(-width, +width)).a;
        float alphaUpRight   = texture2D(u_Tex0, v_TexCoord + vec2(+width, +width)).a;
        float alphaDownLeft  = texture2D(u_Tex0, v_TexCoord + vec2(-width, -width)).a;
        float alphaDownRight = texture2D(u_Tex0, v_TexCoord + vec2(+width, -width)).a;

        bool isBorder = (
            alphaLeft      > 0.0 ||
            alphaRight     > 0.0 ||
            alphaUp        > 0.0 ||
            alphaDown      > 0.0 ||
            alphaUpLeft    > 0.0 ||
            alphaUpRight   > 0.0 ||
            alphaDownLeft  > 0.0 ||
            alphaDownRight > 0.0
        );

        if (isBorder) {
            // 2) Faz um "offset" pulsante para pegar alpha de 4 direções (ou 8, se quiser)
            float offset = (1.0 + sin(u_GlobalTime * speed)) * width;

            // Aqui você pode somar alpha de 4 ou 8 direções. Exemplo com 4:
            float a = 0.0;
            a += texture2D(u_Tex0, v_TexCoord + vec2(+offset,  0.0)).a;
            a += texture2D(u_Tex0, v_TexCoord + vec2(-offset,  0.0)).a;
            a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0,   +offset)).a;
            a += texture2D(u_Tex0, v_TexCoord + vec2( 0.0,   -offset)).a;

            // (Opcional) se quiser diagonais no pulso, pode somar também:
            // a += texture2D(u_Tex0, v_TexCoord + vec2(+offset, +offset)).a;
            // a += texture2D(u_Tex0, v_TexCoord + vec2(-offset, +offset)).a;
            // a += texture2D(u_Tex0, v_TexCoord + vec2(+offset, -offset)).a;
            // a += texture2D(u_Tex0, v_TexCoord + vec2(-offset, -offset)).a;

            // 3) Calcula um "pulse" para alternar entre vermelhoNoel e azulSnow
            float pulse = 0.5 + 0.5 * sin(u_GlobalTime * speed);

            // Faz a interpolação das cores
            vec4 outlineCol = mix(redNoel, blueSnow, pulse);

            // Ajusta a opacidade final do outline com base no 'a' somado
            outlineCol.a = outlineCol.a * a;

            // 4) Mistura "col" (que é alpha 0) com "outlineCol"
            //    (1.0 - col.a) = 1.0, pois col.a é 0 => essentially: gl_FragColor = outlineCol
            gl_FragColor = col + outlineCol * (1.0 - col.a);
        } else {
            discard;
        }
    }
}
