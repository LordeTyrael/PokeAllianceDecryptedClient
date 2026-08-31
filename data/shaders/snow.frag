uniform sampler2D u_Tex0;
uniform sampler2D u_Tex1;
varying vec2 v_TexCoord;
uniform float u_GlobalTime;
uniform float u_Level;
uniform vec2 u_TexScale;

const vec2 snow_direction = vec2(-1.0,1.0);
const float snow_speed = 0.10;
const float snow_pressure = 0.5;
const float snow_zoom = 1.0;

const vec4 mistcolor = vec4(1.0,1.0,1.0,1.0);
const float mist_pressure = 0.0;
const float bg_pressure = 1.0;

void main(void)
{
    vec2 b = vec2(u_TexScale.y/u_TexScale.x, 1.0);
    vec2 snow_offset = (v_TexCoord * b  + (snow_direction * u_GlobalTime * (snow_speed * snow_zoom)));
    vec4 snowcol = texture2D(u_Tex1, snow_offset) * snow_pressure;
    vec4 color = texture2D(u_Tex0,v_TexCoord);
    float len = length(v_TexCoord)*1.0;
    vec4 mistcol = mistcolor * len * mist_pressure;
    vec4 outcolor = color * bg_pressure +  snowcol + mistcol;
    gl_FragColor = outcolor * u_Level + (1.0 - u_Level) * color;
}
