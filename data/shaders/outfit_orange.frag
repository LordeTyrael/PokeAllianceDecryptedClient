uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

uniform float u_GlobalTime;
uniform float u_SpriteSize;
uniform vec2 u_Resolution;

void main(void)
{
    // Obtém a cor do pixel atual
    vec4 col = texture2D(u_Tex0, v_TexCoord);
    
    // Define 'width' conforme o tamanho da sprite
    float width;
    if (abs(u_SpriteSize - 64.0) < 0.5)
        width = 1.0 / 64.0;
    else if (abs(u_SpriteSize - 128.0) < 0.5)
        width = 1.0 / 128.0;
    else if (abs(u_SpriteSize - 256.0) < 0.5)
        width = 1.0 / 256.0;
    else
        width = 1.0 / 256.0;
    
    // Se o pixel é parte da sprite, descartamos
    if (col.a > 0.0)
        discard;
    else {
        // Verifica vizinhos
        float alphaLeft      = texture2D(u_Tex0, v_TexCoord + vec2(-width, 0.0)).a;
        float alphaRight     = texture2D(u_Tex0, v_TexCoord + vec2(width, 0.0)).a;
        float alphaUp        = texture2D(u_Tex0, v_TexCoord + vec2(0.0, width)).a;
        float alphaDown      = texture2D(u_Tex0, v_TexCoord + vec2(0.0, -width)).a;
        
        float alphaUpLeft    = texture2D(u_Tex0, v_TexCoord + vec2(-width, width)).a;
        float alphaUpRight   = texture2D(u_Tex0, v_TexCoord + vec2(width, width)).a;
        float alphaDownLeft  = texture2D(u_Tex0, v_TexCoord + vec2(-width, -width)).a;
        float alphaDownRight = texture2D(u_Tex0, v_TexCoord + vec2(width, -width)).a;
        
        bool isBorder = (alphaLeft      > 0.0 ||
                         alphaRight     > 0.0 ||
                         alphaUp        > 0.0 ||
                         alphaDown      > 0.0 ||
                         alphaUpLeft    > 0.0 ||
                         alphaUpRight   > 0.0 ||
                         alphaDownLeft  > 0.0 ||
                         alphaDownRight > 0.0);
                         
        if (isBorder) {
            float pulse = 0.5 + 0.5 * sin(u_GlobalTime * 10.0);
            vec3 darkColor   = vec3(0.3, 0.15, 0.0);   // tom base laranja escuro
            vec3 orangeColor = vec3(0.92, 0.5, 0.0);     // laranja vibrante
            vec3 finalColor  = mix(darkColor, orangeColor, pulse);
            
            gl_FragColor = vec4(finalColor, 0.8);
        } else {
            discard;
        }
    }
}
