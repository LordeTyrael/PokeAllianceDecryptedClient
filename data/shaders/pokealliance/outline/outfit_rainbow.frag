#ifdef GL_ES
precision mediump float;
#endif

uniform sampler2D u_Tex0;
uniform float u_GlobalTime;
uniform float u_SpriteSize;
uniform float u_AlphaThreshold;

varying vec2 v_TexCoord;

void main(void)
{
    vec4 col = texture2D(u_Tex0, v_TexCoord);

    float width;
    if (abs(u_SpriteSize - 64.0) < 0.5) {
        width = 1.0 / 64.0;
    } else if (abs(u_SpriteSize - 128.0) < 0.5) {
        width = 1.0 / 128.0;
    } else if (abs(u_SpriteSize - 256.0) < 0.5) {
        width = 1.0 / 256.0;
    } else {
        width = 1.0 / 240.0;
    }

    // Ignora pixels sólidos
    if (col.a > u_AlphaThreshold) {
        discard;
    } else {
        float alphaLeft      = texture2D(u_Tex0, v_TexCoord + vec2(-width, 0.0)).a;
        float alphaRight     = texture2D(u_Tex0, v_TexCoord + vec2( width, 0.0)).a;
        float alphaUp        = texture2D(u_Tex0, v_TexCoord + vec2( 0.0,   width)).a;
        float alphaDown      = texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  -width)).a;

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
            float speedFactor = 0.5;
            float standardHeight = 256.0;

            float fakePixelsY = v_TexCoord.y * standardHeight;
            float discreteY = floor(fakePixelsY + 0.5);
            float snappedY = discreteY / standardHeight;

            float hue = mod((snappedY - u_GlobalTime * speedFactor) * 3.0, 1.0);

            vec3 rainbowColor = vec3(
                0.5 + 0.5 * sin(hue * 6.28318),
                0.5 + 0.5 * sin(hue * 6.28318 + 2.094),
                0.5 + 0.5 * sin(hue * 6.28318 + 4.188)
            );

            gl_FragColor = vec4(rainbowColor, 0.8);
        } else {
            discard;
        }
    }
}
