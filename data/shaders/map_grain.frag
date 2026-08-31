uniform float u_GlobalTime;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

// Função de ruído simples baseada na coordenada
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

void main()
{
    vec4 col = texture2D(u_Tex0, v_TexCoord);

    // Fixa o padrão de ruído a cada 5 segundos
    float grain = rand(v_TexCoord + floor(u_GlobalTime / 5.0));

    float grainStrength = 0.07;
    col.rgb += (grain - 0.5) * grainStrength;

    gl_FragColor = col;
}