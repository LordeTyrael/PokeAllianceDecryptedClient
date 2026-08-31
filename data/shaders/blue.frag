uniform float u_GlobalTime;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

void main()
{
  vec4 col = texture2D(u_Tex0, v_TexCoord);
  
  float alpha = (sin(u_GlobalTime * 2.0) + 1.0) / 2.0;
  
  vec4 dark_glow = vec4(alpha * vec3(0.25), 0.0);
  col += dark_glow;

  gl_FragColor = col;
}