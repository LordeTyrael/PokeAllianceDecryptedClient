uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;
uniform float u_GlobalTime;
uniform vec4 u_Color;

const vec4 tintColor = vec4(1.0, 0.25, 0.25, 0.60);
const float width = 1.0 / 240.0;
const float speed = 10.0;

void main(void)
{
    vec4 col = texture2D(u_Tex0,v_TexCoord);
    if (col.a > 0.0) {
        discard;
    } else {
        float alphaLeft   = texture2D(u_Tex0, vec2(v_TexCoord.x - width, v_TexCoord.y)).a;
        float alphaRight  = texture2D(u_Tex0, vec2(v_TexCoord.x + width, v_TexCoord.y)).a;
        float alphaUp     = texture2D(u_Tex0, vec2(v_TexCoord.x, v_TexCoord.y + width)).a;
        float alphaDown   = texture2D(u_Tex0, vec2(v_TexCoord.x, v_TexCoord.y - width)).a;

        if (alphaLeft > 0.0 || alphaRight > 0.0 || alphaUp > 0.0 || alphaDown > 0.0) {
            float offset = (1.0+sin(u_GlobalTime*speed))*width;
    
            col.a = col.a * u_Color.a;
            float a = texture2D(u_Tex0, vec2(v_TexCoord.x + offset, v_TexCoord.y)).a +
                      texture2D(u_Tex0, vec2(v_TexCoord.x, v_TexCoord.y - offset)).a +
                      texture2D(u_Tex0, vec2(v_TexCoord.x - offset, v_TexCoord.y)).a +
                      texture2D(u_Tex0, vec2(v_TexCoord.x, v_TexCoord.y + offset)).a;
            vec4 outlineCol = tintColor;
            outlineCol.a = outlineCol.a * a;
            gl_FragColor = col + outlineCol*(1.0-col.a);
        } else {
            discard;
        }
    }
}