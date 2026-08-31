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
    vec4 baseColor = texture2D(u_Tex0, v_TexCoord);
    vec4 texcolor = texture2D(u_Tex0, v_TexCoord2);
    vec4 texcolor2 = texture2D(u_Tex0, v_TexCoord3);

    vec4 modifiedColor = baseColor;
    
    if (texcolor.r > 0.9) {
        modifiedColor *= texcolor.g > 0.9 ? u_Color[0] : u_Color[1];
    } else if (texcolor.g > 0.9) {
        modifiedColor *= u_Color[2];
    } else if (texcolor.b > 0.9) {
        modifiedColor *= u_Color[3];
    }

    modifiedColor.a *= u_Color[0][3];

    if (modifiedColor.a < 0.01) {
        if (texcolor2.a > 0.01) {
            // Calculate single pulse effect based on vertical position and time
            float wave = mod(v_Position.y - mod(u_GlobalTime, 1.0) * u_Resolution.y, u_Resolution.y) / u_Resolution.y;
            float pulse = smoothstep(0.0, 0.1, wave) * smoothstep(0.2, 0.1, wave); // Creates a single wave

            vec3 pulseColor = mix(vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 1.0), pulse);
            gl_FragColor = vec4(pulseColor, 0.8);
        } else {
            discard;
        }
    } else {
        gl_FragColor = modifiedColor;
    }
}
