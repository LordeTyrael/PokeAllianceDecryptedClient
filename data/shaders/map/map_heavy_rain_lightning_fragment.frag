// Fragment Shader (RAIN + FOG + LIGHTNING)
precision mediump float;

varying vec2 v_TexCoord;
varying vec2 v_RainCoord;
varying vec2 v_FogCoord;
varying vec2 v_LightCoord;

uniform sampler2D u_Tex0;   // terreno
uniform sampler2D u_Tex1;   // chuva
uniform sampler2D u_Tex2;   // névoa
uniform sampler2D u_Tex3;   // relâmpago

uniform vec4 u_Color;       // tint do terreno
uniform vec4 u_Opacity;     // opacidade do relâmpago
uniform highp float u_GlobalTime;

const float rainPressure     = 0.8;   // intensidade da chuva
const float fogPressure      = 0.3;   // intensidade da névoa
const float lightningInterval = 1.0; // intervalo entre relâmpagos

void main()
{
    // camada base
    vec4 color = texture2D(u_Tex0, v_TexCoord) * u_Color;

    // chuva
    color += texture2D(u_Tex1, v_RainCoord) * rainPressure;

    // névoa
    color += texture2D(u_Tex2, v_FogCoord)  * fogPressure;

    // relâmpago periódico
    if (mod(u_GlobalTime, lightningInterval) < 0.1) {
        color += texture2D(u_Tex3, v_LightCoord) * u_Opacity;
    }

    // descarta pixels quase transparentes
    if (color.a < 0.01) discard;

    gl_FragColor = color;
}
